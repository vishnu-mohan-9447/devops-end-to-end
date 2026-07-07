output "ec2_instance_id" {
  description = "ID of the EC2 instance, null when compute_type is eks"
  value       = var.compute_type == "ec2" ? aws_instance.this[0].id : null
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance, null when compute_type is eks"
  value       = var.compute_type == "ec2" ? aws_instance.this[0].public_ip : null
}

output "ec2_private_ip" {
  description = "Private IP of the EC2 instance, null when compute_type is eks"
  value       = var.compute_type == "ec2" ? aws_instance.this[0].private_ip : null
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster, null when compute_type is ec2"
  value       = var.compute_type == "eks" ? aws_eks_cluster.lms[0].name : null
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster, null when compute_type is ec2"
  value       = var.compute_type == "eks" ? aws_eks_cluster.lms[0].endpoint : null
}

output "eks_cluster_certificate_authority" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  value       = var.compute_type == "eks" ? aws_eks_cluster.lms[0].certificate_authority[0].data : null
  sensitive   = true
}

output "eks_node_role_arn" {
  description = "IAM role ARN used by the EKS worker nodes"
  value       = var.compute_type == "eks" ? aws_iam_role.eks_node[0].arn : null
}

output "eks_cluster_oidc_issuer" {
  description = "OIDC issuer URL for the EKS cluster - needed to set up IRSA (IAM Roles for Service Accounts)"
  value       = var.compute_type == "eks" ? aws_eks_cluster.lms[0].identity[0].oidc[0].issuer : null
}
