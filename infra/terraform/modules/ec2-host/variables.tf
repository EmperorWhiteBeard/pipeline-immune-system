variable "instance_name" {
  description = "Name tag for the EC2 instance and related resources"
  type        = string
  default     = "sentinelops"
}

variable "instance_type" {
  description = "AWS EC2 instance type (e.g., t3.medium, m7i-flex.large)"
  type        = string
  default     = "m7i-flex.large"
}

variable "allowed_cidr" {
  description = "Your public IP address in CIDR notation (e.g., 203.0.113.0/32). All service ports are restricted to this IP only for security."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to place the security group in. Leave empty to use the default VPC."
  type        = string
  default     = ""
}

variable "repo_url" {
  description = "Git repository URL to clone onto the instance"
  type        = string
  default     = "https://github.com/EmperorWhiteBeard/pipeline-immune-system.git"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}
