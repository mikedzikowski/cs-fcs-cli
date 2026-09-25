###############################################################################
# Suppression demo: fcs-scan ignore directives
#
# The two resources below are as misconfigured as the ones in main.tf, but the
# directives above them suppress the findings, so they do NOT appear in scan
# results. Delete a directive and re-scan to watch the findings reappear.
#
#   fcs scan iac -p examples/terraform/ignore-directives.tf
#
# Scope:
#   fcs-scan ignore-line   suppresses findings on the next line only
#   fcs-scan ignore-block  suppresses findings for the whole block below
#
# Comment syntax: # for Terraform/YAML/Kubernetes/Dockerfile/Ansible,
#                 // for Terraform, ; for Ansible INI inventories
#
# Suppressed findings leave no audit trail in reports. Document the rationale
# separately if you rely on this in production.
###############################################################################

# fcs-scan ignore-block
resource "aws_security_group" "suppressed_wide_open" {
  name        = "fcs-demo-suppressed-sg"
  description = "Findings for this whole block are suppressed"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "partially_suppressed" {
  bucket = "fcs-demo-partially-suppressed"
}

# ignore-line must sit directly above the line the finding anchors to, which is
# the offending *attribute* - not the resource declaration. Putting the directive
# above `resource` here would suppress nothing, because the public-ACL rule
# reports on the `acl` line.
resource "aws_s3_bucket_acl" "suppressed_acl" {
  bucket = aws_s3_bucket.partially_suppressed.id
  # fcs-scan ignore-line
  acl = "public-read"
}

# No directive here, so this one still reports.
resource "aws_ebs_volume" "still_reports" {
  availability_zone = "us-east-1a"
  size              = 10
  encrypted         = false
}
