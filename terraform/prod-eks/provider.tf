provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Both providers below authenticate to the EKS cluster created by
# module.eks in this same apply, using a short-lived token from the AWS
# CLI's EKS auth plugin - no static kubeconfig file needed, and no
# separate `aws eks update-kubeconfig` step required just to run
# `terraform apply` (you'll still want that for your own kubectl use).

provider "kubernetes" {
  host                   = module.eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate_authority)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate_authority)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name, "--region", var.aws_region]
    }
  }
}

