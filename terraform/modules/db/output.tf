output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "Connection endpoint (host:port) for the RDS instance"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname of the RDS instance, without port"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the RDS instance is listening on"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the default database"
  value       = aws_db_instance.this.db_name
}

output "db_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master username/password (null if manage_master_user_password = false)"
  value       = var.manage_master_user_password ? aws_db_instance.this.master_user_secret[0].secret_arn : null
}
