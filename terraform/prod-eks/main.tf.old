# ============================================================
# prod-eks root module
# Provisions: VPC (public+private subnets, NAT), EKS cluster +
# managed node group, and an RDS PostgreSQL instance for the
# production environment.
# ============================================================

module "network" {
  source = "../modules/network"

  name                 = "${var.project_name}-${var.environment}"
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = true # required: private-subnet EKS nodes need egress to pull images
  tags                 = var.tags
}

module "eks" {
  source = "../modules/compute"

  compute_type        = "eks"
  name                = var.cluster_name
  environment         = var.environment
  subnet_ids          = module.network.private_subnet_ids
  vpc_id              = module.network.vpc_id
  cluster_version     = var.cluster_version
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  tags                = var.tags
}

# RDS lives in the private subnets and only accepts traffic
# from inside the VPC (i.e. from EKS pods/nodes).
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allow Postgres access from within the VPC only"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "Postgres from within the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  })
}

module "rds" {
  source = "../modules/db"

  identifier                  = "${var.project_name}-${var.environment}-db"
  environment                 = var.environment
  engine_version              = var.db_engine_version
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true # AWS generates + stores the password in Secrets Manager
  subnet_ids                  = module.network.private_subnet_ids
  vpc_security_group_ids      = [aws_security_group.rds.id]
  multi_az                    = var.db_multi_az
  publicly_accessible         = false
  tags                        = var.tags
}

# ---------------- Root-level outputs ----------------

output "vpc_id" {
  value = module.network.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.eks_cluster_endpoint
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "rds_address" {
  description = "RDS hostname to use as DB_HOST in the backend's environment/ConfigMap"
  value       = module.rds.db_address
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master username/password JSON ({\"username\":..,\"password\":..}). Retrieve it with: aws secretsmanager get-secret-value --secret-id <this-arn>. In Phase 7 the backend Deployment/Secret can pull this via IRSA or an External Secrets Operator instead of a hardcoded K8s Secret."
  value       = module.rds.db_master_user_secret_arn
}
