module "ec2_host" {
  source = "../../modules/ec2-host"

  instance_name    = var.instance_name
  instance_type    = var.instance_type
  allowed_cidr     = var.allowed_cidr
  vpc_id           = var.vpc_id
  repo_url         = var.repo_url
  root_volume_size = var.root_volume_size
}
