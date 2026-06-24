#!/usr/bin/env bash
# Tears down the Stage 0 AWS environment: destroys the EC2 instance and
# associated resources created by Terraform.
#
# Usage: ./infra/scripts/teardown.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$REPO_ROOT/infra/terraform/environments/local"

echo "==> Destroying AWS EC2 instance and related resources"
cd "$TF_DIR"
terraform destroy

echo "==> Teardown complete."
