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
  default     = "test"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "cloudcampus-lms"
    Environment = "test"
    ManagedBy   = "terraform"
  }
}

# ---------------- Networking ----------------

variable "vpc_cidr" {
  description = "CIDR block for the test VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability zones for the test VPC"
  type        = list(string)
  default     = ["us-east-1a"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs - the Jenkins/dev host lives here"
  type        = list(string)
  default     = ["10.20.0.0/24"]
}

# ---------------- Jenkins / dev host (EC2) ----------------

variable "instance_type" {
  description = "EC2 instance type for the Jenkins/dev host"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the Jenkins host"
  type        = list(string)
}

variable "allowed_admin_cidrs" {
  description = "CIDR blocks allowed to reach Jenkins UI and the dev app ports"
  type        = list(string)
}
