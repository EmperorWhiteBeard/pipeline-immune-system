variable "cluster_name" {
  description = "Name of the local kind cluster"
  type        = string
  default     = "sentinelops"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}
