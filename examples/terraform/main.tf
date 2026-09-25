###############################################################################
# Platform: Terraform
# Purpose:  Every resource below is intentionally misconfigured to trigger
#           FCS CLI IaC detections. DO NOT APPLY THIS CODE.
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------------------
# S3: public ACL, no encryption, no versioning, no logging, no public-access block
# Categories: Access Control, Encryption, Backup, Observability
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "public_data" {
  bucket = "fcs-demo-public-data-bucket"
}

resource "aws_s3_bucket_acl" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  acl    = "public-read-write"
}

resource "aws_s3_bucket_versioning" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "public_data" {
  bucket                  = aws_s3_bucket.public_data.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:*"
      Resource  = "${aws_s3_bucket.public_data.arn}/*"
    }]
  })
}

# ---------------------------------------------------------------------------
# Security group: world-open SSH, RDP, and all-egress
# Category: Networking and Firewall
# ---------------------------------------------------------------------------
resource "aws_security_group" "wide_open" {
  name        = "fcs-demo-wide-open"
  description = "Intentionally permissive for FCS detection demo"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RDP from anywhere"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "All ports all protocols"
    from_port        = 0
    to_port          = 65535
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# EC2: IMDSv1 allowed, unencrypted root volume, public IP, no monitoring
# Categories: Insecure Configurations, Encryption, Observability
# ---------------------------------------------------------------------------
resource "aws_instance" "legacy_metadata" {
  ami                         = "ami-0abcdef1234567890"
  instance_type               = "t3.large"
  associate_public_ip_address = true
  monitoring                  = false
  vpc_security_group_ids      = [aws_security_group.wide_open.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  root_block_device {
    encrypted = false
  }

  user_data = <<-EOF
    #!/bin/bash
    export DB_PASSWORD="SuperSecretP@ssw0rd123"
    curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
  EOF
}

resource "aws_ebs_volume" "unencrypted" {
  availability_zone = "us-east-1a"
  size              = 100
  encrypted         = false
}

# ---------------------------------------------------------------------------
# RDS: publicly accessible, unencrypted, no backups, no deletion protection
# Categories: Access Control, Encryption, Backup
# ---------------------------------------------------------------------------
resource "aws_db_instance" "exposed" {
  identifier                          = "fcs-demo-exposed-db"
  engine                              = "mysql"
  engine_version                      = "8.0"
  instance_class                      = "db.t3.medium"
  allocated_storage                   = 20
  username                            = "admin"
  password                            = "Password123!"
  publicly_accessible                 = true
  storage_encrypted                   = false
  backup_retention_period             = 0
  deletion_protection                 = false
  skip_final_snapshot                 = true
  multi_az                            = false
  auto_minor_version_upgrade          = false
  iam_database_authentication_enabled = false
}

# ---------------------------------------------------------------------------
# IAM: full admin wildcard policy, no MFA condition
# Category: Access Control
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "god_mode" {
  name = "fcs-demo-god-mode"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "assume_by_anyone" {
  name = "fcs-demo-assume-by-anyone"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ---------------------------------------------------------------------------
# Logging / monitoring gaps
# Categories: Observability, Encryption
# ---------------------------------------------------------------------------
resource "aws_cloudtrail" "weak" {
  name                          = "fcs-demo-weak-trail"
  s3_bucket_name                = aws_s3_bucket.public_data.id
  is_multi_region_trail         = false
  enable_log_file_validation    = false
  include_global_service_events = false
}

resource "aws_cloudwatch_log_group" "no_retention" {
  name              = "/fcs-demo/no-retention"
  retention_in_days = 0
}

resource "aws_sqs_queue" "unencrypted" {
  name = "fcs-demo-unencrypted-queue"
}

resource "aws_sns_topic" "unencrypted" {
  name = "fcs-demo-unencrypted-topic"
}

# ---------------------------------------------------------------------------
# Secrets Manager / KMS weaknesses
# Categories: Secret Management, Encryption
# ---------------------------------------------------------------------------
resource "aws_kms_key" "no_rotation" {
  description             = "fcs-demo key without rotation"
  enable_key_rotation     = false
  deletion_window_in_days = 7
}

resource "aws_efs_file_system" "unencrypted" {
  creation_token = "fcs-demo-efs"
  encrypted      = false
}
