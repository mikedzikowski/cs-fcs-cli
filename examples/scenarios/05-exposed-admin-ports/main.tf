###############################################################################
# SCENARIO: Unauthenticated admin and datastore ports exposed to the internet
#
# Every one of these ports has been used for mass compromise in the wild:
# Docker API, Kubernetes API/etcd, Redis, MongoDB, Elasticsearch, Memcached,
# Jenkins, Kibana, RabbitMQ, VNC, SMB, Telnet, and unauthenticated Prometheus.
#
# Attack path this models:
#   internet -> :2375 unauthenticated Docker API -> container with host mount
#            -> host root; or :6379 Redis with no auth -> write SSH keys
#
# DO NOT APPLY.
###############################################################################

provider "aws" {
  region = "us-east-1"
}

# Container runtime and orchestrator control planes wide open
# Category: Networking and Firewall
resource "aws_security_group" "container_control_plane" {
  name        = "scenario-exposed-container-mgmt"
  description = "Container and orchestrator admin ports open to the internet"

  ingress {
    description = "Docker API, unauthenticated and unencrypted"
    from_port   = 2375
    to_port     = 2376
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "etcd, which holds every cluster secret"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "kubelet read-write API"
    from_port   = 10250
    to_port     = 10255
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Datastores that ship with no authentication by default
# Category: Networking and Firewall
resource "aws_security_group" "datastores" {
  name        = "scenario-exposed-datastores"
  description = "Unauthenticated datastore ports open to the internet"

  ingress {
    description = "Redis, no auth by default"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MongoDB, historically unauthenticated"
    from_port   = 27017
    to_port     = 27019
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Elasticsearch REST and transport"
    from_port   = 9200
    to_port     = 9300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Memcached, trivially amplified for DDoS"
    from_port   = 11211
    to_port     = 11211
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Cassandra"
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RabbitMQ management UI with guest/guest"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Legacy and remote-desktop protocols that should never face the internet
# Category: Networking and Firewall
resource "aws_security_group" "legacy_protocols" {
  name        = "scenario-exposed-legacy"
  description = "Cleartext and remote-desktop protocols open to the internet"

  ingress {
    description = "Telnet, fully cleartext"
    from_port   = 23
    to_port     = 23
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "FTP, credentials in cleartext"
    from_port   = 20
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SMB, the EternalBlue and ransomware highway"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NetBIOS"
    from_port   = 137
    to_port     = 139
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "VNC, frequently passwordless"
    from_port   = 5900
    to_port     = 5901
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "rsync"
    from_port   = 873
    to_port     = 873
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "LDAP, unencrypted"
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CI/CD and observability dashboards, which are effectively RCE if unauthenticated
# Category: Networking and Firewall
resource "aws_security_group" "dashboards" {
  name        = "scenario-exposed-dashboards"
  description = "CI and monitoring dashboards open to the internet"

  ingress {
    description = "Jenkins, script console is RCE"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kibana"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus, no auth in the default build"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Spark master UI"
    from_port   = 7077
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
