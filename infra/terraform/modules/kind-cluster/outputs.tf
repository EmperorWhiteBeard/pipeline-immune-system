output "cluster_name" {
  description = "Name of the created kind cluster"
  value       = kind_cluster.this.name
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file for this cluster"
  value       = kind_cluster.this.kubeconfig_path
}

output "client_certificate" {
  description = "Client certificate for cluster auth"
  value       = kind_cluster.this.client_certificate
  sensitive   = true
}

output "endpoint" {
  description = "Kubernetes API server endpoint"
  value       = kind_cluster.this.endpoint
}
