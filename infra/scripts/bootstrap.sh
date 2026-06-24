#!/usr/bin/env bash
# Stage 0 bootstrap: provisions an AWS EC2 instance (m7i-flex.large) with
# Terraform, then the instance self-bootstraps Docker, k3s, and the CI stack
# via cloud-init.
#
# Usage: ./infra/scripts/bootstrap.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$REPO_ROOT/infra/terraform/environments/local"
TFVARS="$TF_DIR/terraform.tfvars"

echo "==> Checking prerequisites"
for cmd in terraform aws; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' not found on PATH. Install it before continuing." >&2
    exit 1
  fi
done

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not authenticated. Run 'aws configure' first." >&2
  exit 1
fi

if [ ! -f "$TFVARS" ]; then
  echo "ERROR: $TFVARS not found." >&2
  echo "  Copy terraform.tfvars.example and set your public IP:" >&2
  echo "    cp $TF_DIR/terraform.tfvars.example $TFVARS" >&2
  echo "    # edit $TFVARS and set allowed_cidr to YOUR_PUBLIC_IP/32" >&2
  exit 1
fi

echo "==> Provisioning EC2 instance with Terraform"
cd "$TF_DIR"
terraform init -upgrade
terraform apply

PUBLIC_IP="$(terraform output -raw public_ip)"

echo ""
echo "==> Stage 0 is deploying on AWS."
echo "    Instance IP:  $PUBLIC_IP"
echo "    Region:       $(terraform output -raw -var aws_region 2>/dev/null || echo 'ap-south-1 (default)')"
echo ""
echo "==> Save the private key so you can SSH in:"
echo "    terraform output -raw private_key_pem > sentinelops-key.pem"
echo "    chmod 600 sentinelops-key.pem"
echo "    ssh -i sentinelops-key.pem ubuntu@$PUBLIC_IP"
echo ""
echo "==> Service URLs (available after cloud-init finishes, ~2-3 min):"
echo "    Jenkins:    http://$PUBLIC_IP:8080"
echo "    SonarQube:  http://$PUBLIC_IP:9000  (admin / admin)"
echo "    Nexus:      http://$PUBLIC_IP:8081"
echo ""
echo "Next: SSH in and verify the stack is up, then move to Stage 1 (Spring Boot app)."
