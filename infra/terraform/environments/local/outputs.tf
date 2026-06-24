output "public_ip" {
  description = "Public IP of the SentinelOps EC2 instance"
  value       = module.ec2_host.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = module.ec2_host.ssh_command
}

output "private_key_pem" {
  description = "Private key PEM — save to a .pem file and use with ssh -i"
  value       = module.ec2_host.private_key_pem
  sensitive   = true
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${module.ec2_host.public_ip}:8080"
}

output "sonarqube_url" {
  description = "SonarQube URL"
  value       = "http://${module.ec2_host.public_ip}:9000"
}

output "nexus_url" {
  description = "Nexus URL"
  value       = "http://${module.ec2_host.public_ip}:8081"
}
