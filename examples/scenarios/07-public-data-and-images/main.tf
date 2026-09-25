###############################################################################
# SCENARIO: Data and machine images shared with the entire internet
#
# Public object storage, disk snapshots and AMIs shared with "all", a public
# container registry, and an unauthenticated Lambda function URL. This is the
# category behind most "open bucket" breach headlines.
#
# Attack path this models:
#   attacker enumerates public buckets / public snapshots -> mounts a copy of
#   your disk offline -> harvests credentials and data, with no auth at all
#
# DO NOT APPLY.
###############################################################################

provider "aws" {
  region = "us-east-1"
}

provider "google" {
  project = "scenario-public-data"
}

# --- Public object storage ---------------------------------------------------
# Categories: Access Control, Encryption, Backup, Observability

resource "aws_s3_bucket" "public_backups" {
  bucket = "scenario-public-backups"
}

resource "aws_s3_bucket_acl" "public_backups" {
  bucket = aws_s3_bucket.public_backups.id
  acl    = "public-read-write"
}

resource "aws_s3_bucket_public_access_block" "public_backups" {
  bucket                  = aws_s3_bucket.public_backups.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Anonymous read AND write, so anyone can also plant or destroy objects
resource "aws_s3_bucket_policy" "public_backups" {
  bucket = aws_s3_bucket.public_backups.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AnyoneCanDoAnything"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.public_backups.arn,
        "${aws_s3_bucket.public_backups.arn}/*",
      ]
    }]
  })
}

resource "aws_s3_bucket_versioning" "public_backups" {
  bucket = aws_s3_bucket.public_backups.id
  versioning_configuration {
    status = "Disabled"
  }
}

# GCS bucket readable by all anonymous users
resource "google_storage_bucket" "public_exports" {
  name                        = "scenario-public-exports"
  location                    = "US"
  uniform_bucket_level_access = false
  force_destroy               = true

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket_iam_member" "anyone" {
  bucket = google_storage_bucket.public_exports.name
  role   = "roles/storage.objectAdmin"
  member = "allUsers"
}

# --- Disk images and snapshots shared with everyone -------------------------
# Category: Access Control

# EBS snapshot made publicly restorable: a downloadable copy of the disk
resource "aws_snapshot_create_volume_permission" "public_snapshot" {
  snapshot_id = "snap-0abcdef1234567890"
  account_id  = "all"
}

# AMI shared with every AWS account
resource "aws_ami_launch_permission" "public_ami" {
  image_id = "ami-0abcdef1234567890"
  group    = "all"
}

# RDS snapshot marked public
resource "aws_db_snapshot_copy" "public_db_snapshot" {
  source_db_snapshot_identifier = "arn:aws:rds:us-east-1:111122223333:snapshot:scenario-snap"
  target_db_snapshot_identifier = "scenario-public-db-snapshot"
  shared_accounts               = ["all"]
}

# GCP image shared publicly via IAM
resource "google_compute_image_iam_member" "public_image" {
  image  = "scenario-golden-image"
  role   = "roles/compute.imageUser"
  member = "allUsers"
}

# --- Public container registry ----------------------------------------------
# Categories: Access Control, Supply-Chain

resource "aws_ecr_repository" "public_images" {
  name                 = "scenario-public-images"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository_policy" "public_images" {
  repository = aws_ecr_repository.public_images.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:PutImage"]
    }]
  })
}

# --- Unauthenticated compute entry points -----------------------------------
# Category: Access Control

# Lambda function URL with authorization explicitly disabled
resource "aws_lambda_function_url" "public" {
  function_name      = "scenario-public-fn"
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["*"]
  }
}

# Lambda resource policy allowing invocation by anyone
resource "aws_lambda_permission" "anyone_can_invoke" {
  statement_id  = "AllowPublicInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "scenario-public-fn"
  principal     = "*"
}

# SQS queue any AWS principal can read and write
resource "aws_sqs_queue" "public" {
  name = "scenario-public-queue"
}

resource "aws_sqs_queue_policy" "public" {
  queue_url = aws_sqs_queue.public.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "sqs:*"
      Resource  = aws_sqs_queue.public.arn
    }]
  })
}

# SNS topic open to everyone
resource "aws_sns_topic" "public" {
  name = "scenario-public-topic"
}

resource "aws_sns_topic_policy" "public" {
  arn = aws_sns_topic.public.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["SNS:Subscribe", "SNS:Publish", "SNS:Receive"]
      Resource  = aws_sns_topic.public.arn
    }]
  })
}

# Secrets Manager secret readable by any principal
# Category: Secret Management
resource "aws_secretsmanager_secret" "public" {
  name = "scenario-public-secret"
}

resource "aws_secretsmanager_secret_policy" "public" {
  secret_arn = aws_secretsmanager_secret.public.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "secretsmanager:GetSecretValue"
      Resource  = "*"
    }]
  })
}
