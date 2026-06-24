terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ---------------------------------------------------------------------------
# AMI — latest Ubuntu 22.04 LTS (Jammy) from Canonical
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# VPC — use default VPC if none provided
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  count    = var.vpc_id == "" ? 1 : 0
  default  = true
}

locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
}

# ---------------------------------------------------------------------------
# Key pair — generated in Terraform, private key outputted securely
# ---------------------------------------------------------------------------
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${var.instance_name}-key"
  public_key = tls_private_key.this.public_key_openssh

  tags = {
    Name = "${var.instance_name}-key"
  }
}

# ---------------------------------------------------------------------------
# Security group — locked down to the user's IP only
# ---------------------------------------------------------------------------
resource "aws_security_group" "this" {
  name_prefix = "${var.instance_name}-sg"
  description = "Security group for ${var.instance_name} EC2 instance"
  vpc_id      = local.vpc_id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Jenkins
  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # SonarQube
  ingress {
    description = "SonarQube UI"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Nexus
  ingress {
    description = "Nexus UI / Maven"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Nexus Docker registry
  ingress {
    description = "Nexus Docker registry"
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # HTTP (app / NodePort)
  ingress {
    description = "HTTP / app NodePort"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # HTTPS (app / NodePort)
  ingress {
    description = "HTTPS / app NodePort"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # ArgoCD NodePort
  ingress {
    description = "ArgoCD NodePort"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Grafana NodePort
  ingress {
    description = "Grafana NodePort"
    from_port   = 30090
    to_port     = 30090
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Prometheus NodePort
  ingress {
    description = "Prometheus NodePort"
    from_port   = 30030
    to_port     = 30030
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Allow all outbound (Docker pulls, apt, git, etc.)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# IAM — minimal instance profile for future extensibility (e.g., ECR pull)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "this" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.instance_name}-role"
  }
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.this.name
}

# ---------------------------------------------------------------------------
# EC2 instance — Ubuntu 22.04 with Docker, k3s, and CI stack bootstrapped
# ---------------------------------------------------------------------------
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name

  user_data = templatefile("${path.module}/cloud-init.yml", {
    repo_url = var.repo_url
  })

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = var.instance_name
  }

  depends_on = [aws_security_group.this]
}
