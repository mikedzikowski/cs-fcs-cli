###############################################################################
# SCENARIO: Internet-exposed VM on GCP
#
# A Compute Engine instance with an external IP, a firewall rule allowing all
# ports from 0.0.0.0/0, the default service account with cloud-platform scope,
# OS Login disabled, serial console enabled, and Shielded VM turned off.
#
# Attack path this models:
#   internet -> firewall allows all from 0.0.0.0/0 -> VM
#            -> default SA with cloud-platform scope -> project-wide access
#
# DO NOT APPLY.
###############################################################################

provider "google" {
  project = "scenario-exposed-project"
  region  = "us-central1"
}

resource "google_compute_network" "exposed" {
  name                    = "scenario-exposed-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "exposed" {
  name          = "scenario-exposed-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.exposed.id
  # VPC flow logs not configured
  # Category: Observability
  private_ip_google_access = false
}

# Firewall allowing every port from the entire internet
# Category: Networking and Firewall
resource "google_compute_firewall" "allow_all_from_internet" {
  name    = "scenario-allow-all-from-internet"
  network = google_compute_network.exposed.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  # Firewall logging disabled
  # Category: Observability
}

# The exposed instance
# Categories: Insecure Configurations, Access Control, Encryption
resource "google_compute_instance" "exposed" {
  name         = "scenario-exposed-vm"
  machine_type = "e2-standard-2"
  zone         = "us-central1-a"

  # Lets the host forward traffic to other internal ranges
  can_ip_forward = true

  # Deletion protection off
  deletion_protection = false

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
    # No customer-managed encryption key
  }

  network_interface {
    subnetwork = google_compute_subnetwork.exposed.id
    # Empty access_config assigns an ephemeral external IP
    access_config {}
  }

  metadata = {
    # Serial console reachable, OS Login off, project-wide SSH keys allowed
    serial-port-enable     = "TRUE"
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "FALSE"
    startup-script         = <<-EOF
      #!/bin/bash
      echo "root:Password123!" | chpasswd
      sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
      systemctl restart sshd
      curl -sSL http://example.com/agent.sh | bash
    EOF
  }

  # Default service account with full cloud-platform scope
  # Category: Access Control
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Shielded VM protections all disabled
  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = false
    enable_integrity_monitoring = false
  }
}

# Project-wide SSH key metadata, applying to every instance
# Category: Access Control
resource "google_compute_project_metadata" "ssh_keys" {
  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = "root:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQEXAMPLEKEYNOTREAL root"
  }
}
