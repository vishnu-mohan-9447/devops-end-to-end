# ============================================================
# Compute module
# Provisions either an EC2 instance (for Jenkins/dev) or an
# EKS cluster with managed node group (for prod).
# ============================================================

# ----- EC2 Instance (when compute_type = "ec2") -----

resource "aws_instance" "this" {
  count = var.compute_type == "ec2" ? 1 : 0

  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = var.security_group_ids

  tags = merge(var.tags, {
    Name = var.name
  })
}

# ----- EKS Cluster (when compute_type = "eks") -----

# IAM role for the EKS cluster
resource "aws_iam_role" "eks_cluster" {
  count = var.compute_type == "eks" ? 1 : 0

  name = "${var.name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-cluster-role"
  })
}

# Attach the EKS cluster policy
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.compute_type == "eks" ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM role for EKS worker nodes
resource "aws_iam_role" "eks_node" {
  count = var.compute_type == "eks" ? 1 : 0

  name = "${var.name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-node-role"
  })
}

# Attach required policies for worker nodes
resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each = var.compute_type == "eks" ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]) : toset([])

  role       = aws_iam_role.eks_node[0].name
  policy_arn = each.value
}

# Security group for EKS cluster control plane
resource "aws_security_group" "eks_cluster" {
  count       = var.compute_type == "eks" ? 1 : 0
  name        = "${var.name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = data.aws_vpc.current[0].id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-cluster-sg"
  })
}

# Data source to get VPC from subnet
data "aws_vpc" "current" {
  count = var.compute_type == "eks" ? 1 : 0
  id    = var.vpc_id != "" ? var.vpc_id : data.aws_subnet.first[0].vpc_id
}

data "aws_subnet" "first" {
  count = var.compute_type == "eks" ? 1 : 0
  id    = var.subnet_ids[0]
}

# EKS Cluster
resource "aws_eks_cluster" "lms" {
  count    = var.compute_type == "eks" ? 1 : 0
  name     = var.name
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster[0].id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy[0]
  ]

  tags = merge(var.tags, {
    Name = var.name
  })
}

# EKS Managed Node Group
resource "aws_eks_node_group" "lms" {
  count           = var.compute_type == "eks" ? 1 : 0
  cluster_name    = aws_eks_cluster.lms[0].name
  node_group_name = "${var.name}-node-group"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policies
  ]

  tags = merge(var.tags, {
    Name = "${var.name}-node-group"
  })
}
