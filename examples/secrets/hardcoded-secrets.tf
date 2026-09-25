###############################################################################
# Secret Management detections
#
# The FCS CLI scans for embedded secrets in addition to misconfigurations.
# Every value below is a well-known, non-functional placeholder taken from
# public vendor documentation. None of these grant access to anything.
#
# Run with secrets scanning disabled to see the difference:
#   fcs scan iac -p examples/secrets --disable-secrets-scan
###############################################################################

# Hardcoded provider credentials
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

locals {
  # Generic passwords and tokens
  db_password    = "SuperSecretP@ssw0rd123"
  admin_password = "Password123!"
  basic_auth     = "admin:admin"

  # Connection strings with inline credentials
  postgres_url = "postgresql://dbuser:hunter2@db.example.com:5432/appdb"
  mongo_url    = "mongodb://root:examplepass@mongo.example.com:27017/admin"
  redis_url    = "redis://:examplepass@redis.example.com:6379/0"

  # Vendor-style API keys (documentation placeholders)
  slack_webhook = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
  github_pat    = "ghp_000000000000000000000000000000000000"
  stripe_key    = "sk_test_00000000000000000000000000"
  google_api    = "AIzaSy0000000000000000000000000000000000"

  # JWT with a documented example signature
  jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
}

# Private key material committed to source
resource "tls_private_key" "embedded" {
  algorithm = "RSA"
}

variable "ssh_private_key" {
  type        = string
  description = "Private key checked into version control"
  default     = <<-EOT
    -----BEGIN RSA PRIVATE KEY-----
    MIIEowIBAAKCAQEAexampleexampleexampleexampleexampleexampleexample
    THIS IS NOT A REAL KEY - PLACEHOLDER FOR FCS SECRET SCANNING DEMO
    -----END RSA PRIVATE KEY-----
  EOT
}

# Secrets passed into resources in plaintext
resource "aws_db_instance" "with_inline_password" {
  identifier          = "fcs-demo-secrets-db"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "appuser"
  password            = "SuperSecretP@ssw0rd123"
  skip_final_snapshot = true
}

resource "kubernetes_secret" "plaintext" {
  metadata {
    name = "fcs-demo-plaintext-secret"
  }
  data = {
    password = "SuperSecretP@ssw0rd123"
    token    = "sk-demo-not-a-real-token-000000000000"
  }
}
