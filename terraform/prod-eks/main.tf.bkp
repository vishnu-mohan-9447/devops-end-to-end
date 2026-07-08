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
  manage_master_user_password = false # self-managed below - AWS's own auto-generated secret gets a brand new UUID name on every recreation, which is exactly the instability we're avoiding
  password                    = random_password.rds_master.result
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

# Generates a short random string to append to the secret name
resource "random_password" "jwt_secret" {
  length  = 64
  special = false # keep it simple to pass through env vars/JWT libraries without escaping issues
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "cloudcampus-lms/jwt-secret"
  tags = var.tags

  # recovery_window_in_days = 0 means AWS deletes this immediately when
  # Terraform destroys it, instead of soft-deleting with a 30-day recovery
  # window. Without this, `terraform destroy` followed by a fresh `apply`
  # (exactly the workflow this project uses) fails with "already scheduled
  # for deletion" trying to recreate a secret with the same name. Fine to
  # skip the recovery window here since this value is trivially
  # regeneratable - not appropriate for a secret protecting irreplaceable
  # data.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

# ============================================================
# RDS master password - Terraform-managed (not AWS's auto-generated
# manage_master_user_password secret, which gets a brand new UUID name
# every time the RDS instance is recreated - see the note on
# module.rds.manage_master_user_password above). This one keeps a stable,
# predictable name across recreations, so lms-gitops-source's
# external-secret.yaml never needs manual updates after a rebuild.
# ============================================================

resource "random_password" "rds_master" {
  length  = 32
  special = false # avoid characters that need escaping in connection strings
}

resource "aws_secretsmanager_secret" "rds_master_password" {
  name                     = "cloudcampus-lms/rds-master-password"
  tags                     = var.tags
  recovery_window_in_days  = 0
}

resource "aws_secretsmanager_secret_version" "rds_master_password" {
  secret_id     = aws_secretsmanager_secret.rds_master_password.id
  secret_string = random_password.rds_master.result
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
      # Broad prefix instead of listing individual secret ARNs - covers
      # jwt-secret, rds-master-password, and anything else added under
      # this project's naming convention going forward, without ever
      # needing an IAM policy update again.
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:cloudcampus-lms/*"
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

  # Without this, ArgoCD has no built-in health check for the
  # external-secrets.io CRDs and treats any ExternalSecret as "Healthy"
  # the instant it's created - even though the actual Kubernetes Secret it
  # produces is created asynchronously, a moment later, by the ESO
  # controller. That gap is exactly what caused the migration Job (a
  # PreSync hook that depends on that Secret) to race ahead and fail
  # intermittently. This teaches ArgoCD to only report Healthy once the
  # ExternalSecret's own "Ready" condition is actually True, so hook-wave
  # ordering genuinely waits for it rather than just hoping the timing
  # works out.
  set {
    name  = "configs.cm.resource\\.customizations\\.health\\.external-secrets\\.io_ExternalSecret"
    value = <<-LUA
      hs = {}
      if obj.status ~= nil and obj.status.conditions ~= nil then
        for i, condition in ipairs(obj.status.conditions) do
          if condition.type == "Ready" then
            if condition.status == "True" then
              hs.status = "Healthy"
              hs.message = condition.message
              return hs
            else
              hs.status = "Progressing"
              hs.message = condition.message
              return hs
            end
          end
        end
      end
      hs.status = "Progressing"
      hs.message = "Waiting for ExternalSecret to report a Ready condition"
      return hs
    LUA
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


resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.metrics_server_chart_version
  namespace        = "kube-system"
  create_namespace = false

  # No IRSA needed - metrics-server only talks to the kubelet API on each
  # node, not any AWS service.

  depends_on = [module.eks]
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
  description = "Secrets Manager ARN holding the RDS master password (plain string, not JSON - see random_password.rds_master). Stable name across recreations: cloudcampus-lms/rds-master-password."
  value       = aws_secretsmanager_secret.rds_master_password.arn
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
