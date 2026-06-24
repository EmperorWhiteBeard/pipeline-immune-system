# Cloud environment (EKS/GKE) — intentionally not implemented yet.
#
# Plan: this environment is only needed if/when we record a demo on a
# real managed Kubernetes cluster (see project handoff doc, Stage 5).
# It should reuse shared modules where possible (e.g. a future
# `modules/k8s-platform` module for ArgoCD/Prometheus/Grafana install)
# so behavior matches the local environment as closely as possible.
#
# Until then, all development happens against infra/terraform/environments/local.

terraform {
  required_version = ">= 1.5"
}
