#!/usr/bin/env bash
# Tears down the test-dockercompose environment provisioned by
# provision-test-env.sh. Run this to avoid leaving billable
# resources running between work sessions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/test-dockercompose"

echo "==> Detecting your current public IP (needed to satisfy variable validation on destroy)"
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"

cd "$TERRAFORM_DIR"
terraform destroy -auto-approve \
  -var="allowed_ssh_cidrs=[\"$MY_IP\"]" \
  -var="allowed_admin_cidrs=[\"$MY_IP\"]"

echo "==> Test environment destroyed."
