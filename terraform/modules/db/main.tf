# ============================================================
# DB module
# Provisions an AWS RDS PostgreSQL instance for the data tier.
# Used by the prod-eks environment; the test-dockercompose
# environment uses a Postgres container instead (see
# database/Dockerfile in the application repo).
# ============================================================

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.username
  port     = 5432

  # Password management: by default AWS generates and stores the master
  # password in Secrets Manager (rotatable, never touches Terraform state
  # as plaintext, never appears in .tfvars or CLI history). Set
  # manage_master_user_password = false and supply var.password only if
  # you have a specific reason to self-manage it.
  # manage_master_user_password must be true or null here, never a literal
  # false - the AWS provider's schema treats any explicitly-assigned value
  # (including false) as "configured" and conflicts with `password`, even
  # though logically only one should be active. null (omitted) is the only
  # value that actually satisfies ConflictsWith when self-managing.
  manage_master_user_password   = var.manage_master_user_password ? true : null
  password                      = var.manage_master_user_password ? null : var.password
  master_user_secret_kms_key_id = var.manage_master_user_password ? var.master_user_secret_kms_key_id : null

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  multi_az             = var.multi_az
  publicly_accessible  = var.publicly_accessible
  deletion_protection  = false

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot"

  tags = merge(var.tags, {
    Environment = var.environment
  })
}
