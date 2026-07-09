variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used as a prefix for resource names"
  type        = string
  default     = "cloudcampus-lms"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "cloudcampus-lms"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# ---------------- Networking ----------------

variable "vpc_cidr" {
  description = "CIDR block for the prod VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "azs" {
  description = "Availability zones for the prod VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ) - used for load balancers / NAT"
  type        = list(string)
  default     = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (one per AZ) - used for EKS nodes and RDS"
  type        = list(string)
  default     = ["10.10.10.0/24", "10.10.11.0/24"]
}

# ---------------- EKS ----------------

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cloudcampus-lms-prod"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

# ---------------- RDS ----------------

variable "db_engine_version" {
  description = "PostgreSQL engine version for RDS"
  type        = string
  default     = "16.3"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the application database"
  type        = string
  default     = "lms_db"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "lms_user"
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ for the RDS instance"
  type        = bool
  default     = true
}

# ---------------- Helm addon chart versions ----------------
# Pinned deliberately - verify still-current before applying with:
#   helm search repo <repo>/<chart> --versions

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version (argoproj/argo-helm)"
  type        = string
  default     = "10.1.2"
}

variable "nginx_ingress_chart_version" {
  description = "F5 NGINX Ingress Controller (OSS) Helm chart version"
  type        = string
  default     = "2.6.1"
}

variable "cert_manager_chart_version" {
  description = "cert-manager Helm chart version (jetstack/cert-manager)"
  type        = string
  default     = "1.20.0"
}

variable "external_secrets_chart_version" {
  description = "external-secrets Helm chart version - NOT independently verified, check helm search repo external-secrets/external-secrets --versions before applying"
  type        = string
  default     = "2.7.0"
}
variable "metrics_server_chart_version" {
  description = "metrics-server Helm chart version (kubernetes-sigs/metrics-server) - required for HPA to read CPU/memory metrics"
  type        = string
  default     = "3.13.1"
}
