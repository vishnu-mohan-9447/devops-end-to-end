# Remote state backend for the prod-eks environment.
# Terraform backend blocks cannot use variables, so update these
# values directly (or pass them via `terraform init -backend-config=...`).
#
# Prerequisite: create the S3 bucket once, outside of this Terraform
# configuration (e.g. manually or via a separate bootstrap stack),
# before running `terraform init` here. No DynamoDB table needed -
# Terraform >= 1.10 locks state natively on S3 via use_lockfile.

terraform {
  backend "s3" {
    bucket       = "cloudcampus1-lms-tfstate"
    key          = "prod-eks/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

