variable "identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
}

variable "environment" {
  description = "Environment name, e.g. test or prod"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit for RDS storage autoscaling in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the default database to create"
  type        = string
}

variable "username" {
  description = "Master username for the database"
  type        = string
}

variable "manage_master_user_password" {
  description = "If true (default), AWS generates and stores the master password in Secrets Manager automatically - no plaintext password ever passed through Terraform."
  type        = bool
  default     = true
}

variable "master_user_secret_kms_key_id" {
  description = "Optional customer-managed KMS key ID used to encrypt the auto-generated Secrets Manager secret. Leave null to use the default AWS-managed key."
  type        = string
  default     = null
}

variable "password" {
  description = "Master password for the database. Only used when manage_master_user_password = false. Prefer leaving password management to Secrets Manager."
  type        = string
  sensitive   = true
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group (private subnets recommended)"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach to the RDS instance"
  type        = list(string)
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the RDS instance should have a public IP"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Whether to skip taking a final snapshot when the instance is destroyed"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
