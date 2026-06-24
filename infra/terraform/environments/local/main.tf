terraform {
  required_version = ">= 1.5"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6"
    }
  }
}

provider "kind" {}

module "kind_cluster" {
  source = "../../modules/kind-cluster"

  cluster_name = var.cluster_name
  worker_count = var.worker_count
}
