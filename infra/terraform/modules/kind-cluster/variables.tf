variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "sentinelops"
}

variable "worker_count" {
  description = "Number of worker nodes in addition to the control-plane node"
  type        = number
  default     = 1
}
