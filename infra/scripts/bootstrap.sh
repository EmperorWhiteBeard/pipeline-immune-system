#!/usr/bin/env bash
# Stage 0 bootstrap: brings up the kind cluster (via Terraform) and the
# Jenkins/SonarQube/Nexus stack (via Docker Compose).
#
# Usage: ./infra/scripts/bootstrap.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$REPO_ROOT/infra/terraform/environments/local"
COMPOSE_FILE="$REPO_ROOT/infra/docker-compose.cicd.yml"

echo "==> Checking prerequisites"
for cmd in docker terraform kubectl kind; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' not found on PATH. Install it before continuing." >&2
    exit 1
  fi
done

# SonarQube's bundled Elasticsearch refuses to start unless the host's
# vm.max_map_count is raised. This is a host-level sysctl, not something
# Docker Compose can set for you, so check and warn explicitly.
CURRENT_MAX_MAP_COUNT="$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)"
if [ "$CURRENT_MAX_MAP_COUNT" -lt 262144 ]; then
  echo
  echo "WARNING: vm.max_map_count is $CURRENT_MAX_MAP_COUNT (SonarQube needs >= 262144)."
  echo "  Run this once on your host, then re-run this script:"
  echo "    sudo sysctl -w vm.max_map_count=262144"
  echo "  To make it permanent, add 'vm.max_map_count=262144' to /etc/sysctl.conf"
  echo
  exit 1
fi

echo "==> Provisioning kind cluster with Terraform"
cd "$TF_DIR"
terraform init -upgrade
terraform apply -auto-approve

echo "==> Pointing kubectl at the new cluster"
KUBECONFIG_PATH="$(terraform output -raw kubeconfig_path)"
export KUBECONFIG="$KUBECONFIG_PATH"
kubectl cluster-info

echo "==> Starting Jenkins / SonarQube / Nexus"
docker compose -f "$COMPOSE_FILE" up -d

echo
echo "==> Stage 0 is up."
echo "    Cluster:    $(terraform output -raw cluster_name) (KUBECONFIG=$KUBECONFIG_PATH)"
echo "    Jenkins:    http://localhost:8080"
echo "    SonarQube:  http://localhost:9000  (default login admin/admin)"
echo "    Nexus:      http://localhost:8081  (initial password: docker exec sentinelops-nexus cat /nexus-data/admin.password)"
echo
echo "Next: open each UI once to confirm it's reachable, then move to Stage 1 (the Spring Boot app)."
