output "instance_id" {
  description = "ID of the created EC2 instance"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.this.private_ip
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ${var.instance_name}-key.pem ubuntu@${aws_instance.this.public_ip}"
}

output "key_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.this.key_name
}

output "private_key_pem" {
  description = "Private key in PEM format (save this to a .pem file)"
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the created security group"
  value       = aws_security_group.this.id
}
