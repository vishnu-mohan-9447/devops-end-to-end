#!/usr/bin/env bash
# ============================================================
# Fully automates the test/dev environment from your laptop:
#   1. Detects your current public IP (so the SG always matches
#      your laptop, even if your home/office IP has changed)
#   2. terraform apply - provisions VPC + Jenkins EC2 host
#   3. Waits for SSH to come up
#   4. Generates ansible/inventory/hosts.ini from the Terraform output
#   5. Runs the Ansible playbook to install Java and Jenkins
#
# Usage:
#   ./scripts/provision-test-env.sh
#
# Requirements on your laptop:
#   - terraform, ansible-playbook, aws cli (configured), nc (netcat)
#   - an EC2 key pair matching test-dockercompose/terraform.tfvars
#     key_name, with the .pem downloaded to SSH_KEY below
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/test-dockercompose"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/cloudcampus-lms-key.pem}"

if [ ! -f "$SSH_KEY" ]; then
  echo "ERROR: SSH private key not found at $SSH_KEY"
  echo "Set SSH_KEY=/path/to/your-key.pem before running this script."
  exit 1
fi
chmod 400 "$SSH_KEY"

echo "==> Detecting your current public IP"
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"
echo "    Using $MY_IP for SSH + admin access"

echo "==> Provisioning infrastructure with Terraform"
cd "$TERRAFORM_DIR"
terraform init -input=false
terraform apply -auto-approve \
  -var="allowed_ssh_cidrs=[\"$MY_IP\"]" \
  -var="allowed_admin_cidrs=[\"$MY_IP\"]"

PUBLIC_IP=$(terraform output -raw jenkins_public_ip)
echo "==> Jenkins host provisioned at: $PUBLIC_IP"

echo "==> Waiting for SSH to become available"
until nc -z -w5 "$PUBLIC_IP" 22 2>/dev/null; do
  echo "    still waiting..."
  sleep 10
done
echo "    SSH is up - giving cloud-init a few more seconds to settle"
sleep 15

echo "==> Generating Ansible inventory"
mkdir -p "$ANSIBLE_DIR/inventory"
cat > "$ANSIBLE_DIR/inventory/hosts.ini" <<EOF
[jenkins]
$PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY

[jenkins:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "==> Running the Ansible playbook (Java and Jenkins)"
cd "$ANSIBLE_DIR"
ansible-playbook -i inventory/hosts.ini site.yml

echo ""
echo "==> Done!"
echo "    Jenkins:  http://$PUBLIC_IP:8081"
echo "    (dev app ports 8080/5000 will be reachable once you deploy via Docker Compose)"
