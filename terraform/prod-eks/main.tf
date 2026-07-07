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

# ============================================================
# JWT signing secret - referenced by lms-gitops-source's
# external-secret.yaml (key: cloudcampus-lms/jwt-secret, property:
# implicit "secret string"). Generated once here; External Secrets
# Operator (IRSA role below) reads it into the lms-backend-secret K8s
# Secret. Never handled as plaintext in git or Jenkins.
# ============================================================

resource "random_password" "jwt_secret" {
  length  = 64
  special = false # keep it simple to pass through env vars/JWT libraries without escaping issues
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "cloudcampus-lms/jwt-secret"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

# ============================================================
# OIDC provider - required for IRSA (IAM Roles for Service Accounts).
# Without this, pods have no way to assume IAM roles at all; they'd
# either get no AWS permissions or (worse) inherit the node's own IAM
# role, which is far too broad.
# ============================================================

data "tls_certificate" "eks_oidc" {
  url = module.eks.eks_cluster_oidc_issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.eks_cluster_oidc_issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = var.tags
}

# ============================================================
# IRSA role for external-secrets - scoped to the secrets this app
# actually needs to read from Secrets Manager.
# ============================================================

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      # Must match the namespace/ServiceAccount name the Helm release
      # below actually creates - default chart values use this name,
      # confirm with: kubectl get sa -n external-secrets
      values = ["system:serviceaccount:external-secrets:external-secrets"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.project_name}-${var.environment}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "external_secrets_permissions" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      module.rds.db_master_user_secret_arn,
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:cloudcampus-lms/jwt-secret*"
    ]
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "${var.project_name}-${var.environment}-external-secrets-policy"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets_permissions.json
}

# ============================================================
# Helm releases - ArgoCD, Ingress, cert-manager, External Secrets
# Chart versions are pinned deliberately (never "latest") for
# reproducibility. Verify they're still current before applying:
#   helm search repo <repo>/<chart> --versions
# ============================================================

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "ClusterIP" # exposed via the Ingress controller below, not a separate LB
  }

  depends_on = [module.eks]
}

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-ingress"
  version          = var.nginx_ingress_chart_version
  namespace        = "nginx-ingress"
  create_namespace = true

  # Defaults to the free NGINX Open Source image. Do NOT add
  # controller.nginxplus / a private-registry.nginx.com image
  # reference here - that switches to the paid NGINX Plus edition.
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.eks]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [module.eks]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # IRSA binding - lets the operator's pod assume external_secrets
  # role above and actually call Secrets Manager.
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_secrets.arn
  }

  depends_on = [module.eks, aws_iam_role_policy.external_secrets]
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

output "external_secrets_iam_role_arn" {
  description = "IRSA role ARN for the external-secrets ServiceAccount - reference this in your SecretStore/ClusterSecretStore manifest if it needs to be specified explicitly"
  value       = aws_iam_role.external_secrets.arn
}

output "argocd_initial_admin_password_command" {
  description = "Run this after apply to retrieve the ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "nginx_ingress_loadbalancer_command" {
  description = "Run this to get the Ingress controller's external LB hostname once it's provisioned"
  value       = "kubectl get svc -n nginx-ingress nginx-ingress-controller -w"
}
