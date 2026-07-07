variable "compute_type" {
  description = "Which compute resource to create: 'ec2' (Jenkins/dev host) or 'eks' (prod cluster)"
  type        = string

  validation {
    condition     = contains(["ec2", "eks"], var.compute_type)
    error_message = "compute_type must be either \"ec2\" or \"eks\"."
  }
}

variable "name" {
  description = "Name for the compute resource (instance Name tag or EKS cluster name)"
  type        = string
}

variable "environment" {
  description = "Environment name, e.g. test or prod"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ---------------- EC2-specific (used when compute_type = "ec2") ----------------

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  description = "Subnet ID to launch the EC2 instance into"
  type        = string
  default     = null
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "Security group IDs to attach to the EC2 instance"
  type        = list(string)
  default     = []
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "user_data" {
  description = "User data script to bootstrap the EC2 instance"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to the EC2 instance"
  type        = string
  default     = null
}

# ---------------- EKS-specific (used when compute_type = "eks") ----------------

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS cluster and node group (private subnets recommended)"
  type        = list(string)
  default     = []
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
  default     = 3
}

variable "node_disk_size" {
  description = "Disk size in GB for each worker node"
  type        = number
  default     = 20
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server endpoint is publicly accessible"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Whether the EKS API server endpoint is accessible from within the VPC"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be launched (optional, derived from subnets if not provided)"
  type        = string
  default     = ""
}
