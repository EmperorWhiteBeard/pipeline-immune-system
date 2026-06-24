terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6"
    }
  }
}

resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # Expose NodePorts to localhost so ArgoCD/Grafana/the app
      # are reachable without extra port-forwarding plumbing.
      extra_port_mappings {
        container_port = 30080
        host_port       = 30080
        protocol        = "TCP"
      }

      extra_port_mappings {
        container_port = 30090
        host_port       = 30090
        protocol        = "TCP"
      }

      extra_port_mappings {
        container_port = 30030
        host_port       = 30030
        protocol        = "TCP"
      }
    }

    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }
  }
}
