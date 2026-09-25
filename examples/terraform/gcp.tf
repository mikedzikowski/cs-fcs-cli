###############################################################################
# Platform: Terraform (google provider)
# Purpose:  GCP-specific misconfigurations for FCS CLI IaC detections.
###############################################################################

provider "google" {
  project = "fcs-demo-project"
  region  = "us-central1"
}

# Storage bucket: public to allUsers, no uniform access, no versioning/logging
# Categories: Access Control, Backup, Observability
resource "google_storage_bucket" "public" {
  name                        = "fcs-demo-public-bucket"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = false

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.public.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Firewall: 0.0.0.0/0 to SSH/RDP/all ports
# Category: Networking and Firewall
resource "google_compute_firewall" "wide_open" {
  name    = "fcs-demo-allow-all"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "0-65535"]
  }

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# Compute instance: public IP, serial port, default SA with full scopes,
# IP forwarding, project-wide SSH keys, shielded VM disabled
# Categories: Insecure Configurations, Access Control
resource "google_compute_instance" "insecure" {
  name         = "fcs-demo-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    serial-port-enable     = "TRUE"
    block-project-ssh-keys = "FALSE"
    enable-oslogin         = "FALSE"
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = false
    enable_integrity_monitoring = false
  }
}

# GKE: legacy ABAC, no network policy, public endpoint, basic auth
# Categories: Access Control, Networking and Firewall
resource "google_container_cluster" "insecure" {
  name               = "fcs-demo-gke"
  location           = "us-central1"
  initial_node_count = 1

  enable_legacy_abac = true

  network_policy {
    enabled = false
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = true
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "world"
    }
  }
}

# Cloud SQL: public, no SSL required, no backups
# Categories: Access Control, Encryption, Backup
resource "google_sql_database_instance" "insecure" {
  name             = "fcs-demo-sql"
  database_version = "POSTGRES_14"
  region           = "us-central1"

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true
      require_ssl  = false

      authorized_networks {
        name  = "world"
        value = "0.0.0.0/0"
      }
    }

    backup_configuration {
      enabled = false
    }
  }

  deletion_protection = false
}

# Over-permissive project IAM binding
# Category: Access Control
resource "google_project_iam_member" "public_owner" {
  project = "fcs-demo-project"
  role    = "roles/owner"
  member  = "allAuthenticatedUsers"
}
