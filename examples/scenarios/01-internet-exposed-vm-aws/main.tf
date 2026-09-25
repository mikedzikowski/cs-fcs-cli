###############################################################################
# SCENARIO: Internet-exposed Linux VM on AWS
#
# A complete, realistic, and completely indefensible deployment: a public
# subnet with an internet gateway, an EC2 instance with a public IP, a security
# group open to 0.0.0.0/0 on every port, an instance profile with full admin,
# IMDSv1 still enabled, and an unencrypted root volume.
#
# Attack path this models:
#   internet -> 0.0.0.0/0 SG on :22 -> VM -> IMDSv1 credential theft
#            -> admin instance profile -> full account takeover
#
# DO NOT APPLY.
###############################################################################

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "exposed" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  # No VPC flow logs, so the intrusion leaves no network record
  # Category: Observability
}

resource "aws_internet_gateway" "exposed" {
  vpc_id = aws_vpc.exposed.id
}

# Public subnet that auto-assigns public IPs to everything launched in it
# Category: Networking and Firewall
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.exposed.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.exposed.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.exposed.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Default network ACL allowing everything in both directions
# Category: Networking and Firewall
resource "aws_default_network_acl" "allow_all" {
  default_network_acl_id = aws_vpc.exposed.default_network_acl_id

  ingress {
    rule_no    = 100
    action     = "allow"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 100
    action     = "allow"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }
}

# Security group exposing SSH, RDP, and every other port to the entire internet
# Category: Networking and Firewall
resource "aws_security_group" "internet_facing" {
  name        = "scenario-exposed-vm-sg"
  description = "Exposes the VM to the whole internet"
  vpc_id      = aws_vpc.exposed.id

  ingress {
    description = "SSH from the entire internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RDP from the entire internet"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Every TCP port, IPv4 and IPv6"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Every protocol"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Unrestricted egress for exfiltration"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instance profile with full administrative access
# Category: Access Control
resource "aws_iam_role" "vm_admin" {
  name = "scenario-exposed-vm-admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vm_admin" {
  role = aws_iam_role.vm_admin.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "vm_admin" {
  name = "scenario-exposed-vm-admin"
  role = aws_iam_role.vm_admin.name
}

# The exposed instance itself
# Categories: Insecure Configurations, Encryption, Access Control, Observability
resource "aws_instance" "exposed_vm" {
  ami                         = "ami-0abcdef1234567890"
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.internet_facing.id]
  iam_instance_profile        = aws_iam_instance_profile.vm_admin.name
  associate_public_ip_address = true
  monitoring                  = false

  # IMDSv1 left enabled, so SSRF on the host yields role credentials
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  root_block_device {
    encrypted   = false
    volume_size = 50
  }

  # Credentials pasted into user data, readable via IMDS
  # Category: Secret Management
  user_data = <<-EOF
    #!/bin/bash
    echo "root:Password123!" | chpasswd
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    curl -sSL http://example.com/agent.sh | bash
  EOF
}

# Elastic IP pinning a stable public address to the exposed host
resource "aws_eip" "exposed_vm" {
  instance = aws_instance.exposed_vm.id
  domain   = "vpc"
}
