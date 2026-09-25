###############################################################################
# Breadth coverage: additional AWS services
#
# The Terraform platform ships ~539 rules. main.tf exercises the common
# S3/EC2/IAM/RDS paths; this file widens coverage across the rest of the AWS
# surface so a scan demonstrates how much the tool actually knows about.
#
# DO NOT APPLY.
###############################################################################

provider "aws" {
  region = "us-east-1"
}

# --- Edge and API layer -----------------------------------------------------
# Categories: Encryption, Observability, Networking and Firewall

resource "aws_cloudfront_distribution" "insecure" {
  enabled = true

  origin {
    domain_name = "origin.example.com"
    origin_id   = "primary"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["SSLv3", "TLSv1"]
    }
  }

  default_cache_behavior {
    target_origin_id = "primary"
    # Allows plain HTTP to the viewer
    viewer_protocol_policy = "allow-all"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  # No WAF, no logging, no geo restriction
  web_acl_id = ""

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "SSLv3"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_api_gateway_rest_api" "insecure" {
  name = "breadth-insecure-api"
}

resource "aws_api_gateway_method" "no_auth" {
  rest_api_id      = aws_api_gateway_rest_api.insecure.id
  resource_id      = aws_api_gateway_rest_api.insecure.root_resource_id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_stage" "no_logging" {
  rest_api_id           = aws_api_gateway_rest_api.insecure.id
  deployment_id         = "dummy"
  stage_name            = "prod"
  xray_tracing_enabled  = false
  cache_cluster_enabled = false
  # No access_log_settings, no client certificate
}

resource "aws_api_gateway_method_settings" "no_cache_encryption" {
  rest_api_id = aws_api_gateway_rest_api.insecure.id
  stage_name  = aws_api_gateway_stage.no_logging.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled                         = false
    logging_level                           = "OFF"
    cache_data_encrypted                    = false
    require_authorization_for_cache_control = false
  }
}

# Load balancers without HTTPS, logging, or deletion protection
resource "aws_lb" "insecure" {
  name                       = "breadth-insecure-lb"
  internal                   = false
  load_balancer_type         = "application"
  enable_deletion_protection = false
  drop_invalid_header_fields = false

  access_logs {
    bucket  = "unused"
    enabled = false
  }
}

resource "aws_lb_listener" "plain_http" {
  load_balancer_arn = aws_lb.insecure.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
    }
  }
}

# --- Analytics and data warehousing ----------------------------------------
# Categories: Encryption, Access Control, Backup

resource "aws_redshift_cluster" "insecure" {
  cluster_identifier  = "breadth-redshift"
  node_type           = "dc2.large"
  master_username     = "admin"
  master_password     = "Password123!"
  publicly_accessible = true
  encrypted           = false
  # No logging, no enhanced VPC routing
  enhanced_vpc_routing                = false
  automated_snapshot_retention_period = 0
  allow_version_upgrade               = false
}

resource "aws_elasticsearch_domain" "insecure" {
  domain_name           = "breadth-es"
  elasticsearch_version = "7.10"

  encrypt_at_rest {
    enabled = false
  }

  node_to_node_encryption {
    enabled = false
  }

  domain_endpoint_options {
    enforce_https       = false
    tls_security_policy = "Policy-Min-TLS-1-0-2019-07"
  }

  # Open access policy
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "es:*"
      Resource  = "*"
    }]
  })
}

resource "aws_msk_cluster" "insecure" {
  cluster_name           = "breadth-msk"
  kafka_version          = "2.8.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = []
    security_groups = []
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT"
      in_cluster    = false
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled = false
      }
      firehose {
        enabled = false
      }
      s3 {
        enabled = false
      }
    }
  }
}

resource "aws_athena_database" "unencrypted" {
  name   = "breadth_athena"
  bucket = "breadth-athena-results"

  encryption_configuration {
    encryption_option = "SSE_S3"
  }
}

resource "aws_athena_workgroup" "unencrypted" {
  name = "breadth-workgroup"

  configuration {
    enforce_workgroup_configuration = false

    result_configuration {
      # No encryption_configuration block
      output_location = "s3://breadth-athena-results/"
    }
  }
}

resource "aws_glue_security_configuration" "weak" {
  name = "breadth-glue-sec"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "DISABLED"
    }
    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "DISABLED"
    }
    s3_encryption {
      s3_encryption_mode = "DISABLED"
    }
  }
}

# --- Containers and orchestration ------------------------------------------
# Categories: Access Control, Observability, Encryption

resource "aws_eks_cluster" "insecure" {
  name     = "breadth-eks"
  role_arn = "arn:aws:iam::111122223333:role/eks"

  # Public endpoint open to the world, no logging, no secrets encryption
  vpc_config {
    endpoint_public_access  = true
    endpoint_private_access = false
    public_access_cidrs     = ["0.0.0.0/0"]
    subnet_ids              = []
  }

  enabled_cluster_log_types = []
}

resource "aws_ecs_cluster" "no_insights" {
  name = "breadth-ecs"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_task_definition" "privileged" {
  family = "breadth-task"

  container_definitions = jsonencode([{
    name                   = "app"
    image                  = "nginx:latest"
    essential              = true
    privileged             = true
    user                   = "root"
    readonlyRootFilesystem = false
    environment = [
      { name = "DB_PASSWORD", value = "Password123!" },
    ]
    # No logConfiguration
  }])
}

resource "aws_ecr_repository" "mutable" {
  name                 = "breadth-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# --- Security, governance, and audit services -------------------------------
# Categories: Observability, Best Practices

resource "aws_config_configuration_recorder" "partial" {
  name     = "breadth-recorder"
  role_arn = "arn:aws:iam::111122223333:role/config"

  recording_group {
    all_supported                 = false
    include_global_resource_types = false
  }
}

resource "aws_ecr_registry_scanning_configuration" "off" {
  scan_type = "BASIC"
}

resource "aws_guardduty_detector" "disabled" {
  enable = false
}

resource "aws_securityhub_account" "maybe" {
  control_finding_generator = "STANDARD_CONTROL"
}

# --- Networking gaps --------------------------------------------------------
# Categories: Observability, Networking and Firewall

resource "aws_vpc" "no_flow_logs" {
  cidr_block = "10.90.0.0/16"
  # No aws_flow_log resource references this VPC
}

resource "aws_default_security_group" "permissive" {
  vpc_id = aws_vpc.no_flow_logs.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_network_acl_rule" "allow_all" {
  network_acl_id = "acl-0abcdef1234567890"
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# --- Workflow, messaging, and ML --------------------------------------------
# Categories: Encryption, Access Control

resource "aws_sagemaker_notebook_instance" "insecure" {
  name          = "breadth-notebook"
  role_arn      = "arn:aws:iam::111122223333:role/sagemaker"
  instance_type = "ml.t3.medium"
  # No kms_key_id, direct internet access left at default
  direct_internet_access = "Enabled"
  root_access            = "Enabled"
}

resource "aws_neptune_cluster" "insecure" {
  cluster_identifier                  = "breadth-neptune"
  storage_encrypted                   = false
  iam_database_authentication_enabled = false
  backup_retention_period             = 1
  skip_final_snapshot                 = true
  enable_cloudwatch_logs_exports      = []
}

resource "aws_dynamodb_table" "no_pitr" {
  name         = "breadth-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled = false
  }
}

resource "aws_backup_vault" "unencrypted" {
  name = "breadth-vault"
  # No kms_key_arn
}

resource "aws_codebuild_project" "insecure" {
  name         = "breadth-codebuild"
  service_role = "arn:aws:iam::111122223333:role/codebuild"

  artifacts {
    type                = "S3"
    location            = "breadth-artifacts"
    encryption_disabled = true
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_SECRET_ACCESS_KEY"
      value = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      type  = "PLAINTEXT"
    }
  }

  source {
    type     = "GITHUB"
    location = "https://github.com/example/repo.git"
  }
}

resource "aws_cloudwatch_log_group" "short_retention" {
  name              = "/breadth/short"
  retention_in_days = 1
  # No kms_key_id
}
