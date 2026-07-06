# ============================================================
# test-dockercompose root module
# Provisions: VPC (public subnet only) and a single EC2 instance
# that runs Jenkins and hosts the Docker Compose dev deployment.
# ============================================================

module "network" {
  source = "../modules/network"

  name                 = "${var.project_name}-${var.environment}"
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = []
  enable_nat_gateway   = false # not needed - the host itself lives in the public subnet
  tags                 = var.tags
}

resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-${var.environment}-jenkins-sg"
  description = "Jenkins host - SSH, Jenkins UI, and dev app ports (frontend/backend/db)"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = var.allowed_admin_cidrs
  }

  ingress {
    description = "Frontend (Docker Compose dev deployment)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_admin_cidrs
  }

  ingress {
    description = "Backend API (Docker Compose dev deployment)"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = var.allowed_admin_cidrs
  }

  ingress {
    description = "SonarQube UI"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.allowed_admin_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-sg"
  })
}

# Latest Ubuntu 22.04 LTS - Ansible (Phase 3) targets this OS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "jenkins_host" {
  source = "../modules/compute"

  compute_type       = "ec2"
  name               = "${var.project_name}-${var.environment}-jenkins"
  environment        = var.environment
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_type
  subnet_id          = module.network.public_subnet_ids[0]
  key_name           = var.key_name
  security_group_ids = [aws_security_group.jenkins.id]
  root_volume_size   = var.root_volume_size
  user_data          = file("${path.module}/user_data.sh")
  tags               = var.tags
}

# ---------------- Root-level outputs ----------------

output "vpc_id" {
  value = module.network.vpc_id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins/dev host - feed this into the Ansible inventory"
  value       = module.jenkins_host.ec2_public_ip
}

output "jenkins_instance_id" {
  value = module.jenkins_host.ec2_instance_id
}
