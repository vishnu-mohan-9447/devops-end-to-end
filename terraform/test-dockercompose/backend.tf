# Remote state backend for the test-dockercompose environment.
# Terraform backend blocks cannot use variables, so update these
# values directly (or pass them via `terraform init -backend-config=...`).
#
# Uses the same state bucket as prod-eks but a different key, so the
# two environments never share or clobber state. No DynamoDB table
# needed - Terraform >= 1.10 locks state natively on S3 via use_lockfile.

terraform {
  backend "s3" {
    bucket       = "cloudcampus1-lms-tfstate"
    key          = "test-dockercompose/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

