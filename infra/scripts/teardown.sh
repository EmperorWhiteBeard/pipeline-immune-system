#!/usr/bin/env bash
# Tears down the Stage 0 environment: stops Jenkins/SonarQube/Nexus and
# destroys the kind cluster. Add -v to also wipe Docker volumes (full reset).
#
# Usage: ./infra/scripts/teardown.sh [-v]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$REPO_ROOT/infra/terraform/environments/local"
COMPOSE_FILE="$REPO_ROOT/infra/docker-compose.cicd.yml"

WIPE_VOLUMES=false
if [ "${1:-}" = "-v" ]; then
  WIPE_VOLUMES=true
fi

echo "==> Stopping Jenkins / SonarQube / Nexus"
if [ "$WIPE_VOLUMES" = true ]; then
  docker compose -f "$COMPOSE_FILE" down -v
else
  docker compose -f "$COMPOSE_FILE" down
fi

echo "==> Destroying kind cluster"
cd "$TF_DIR"
terraform destroy -auto-approve

echo "==> Teardown complete."
