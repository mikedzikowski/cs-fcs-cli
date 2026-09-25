###############################################################################
# SCENARIO: Databases published directly to the internet
#
# Managed databases placed in public subnets with publicly_accessible set, open
# security groups, firewall rules spanning the entire IPv4 space, TLS not
# required, encryption off, and backups disabled.
#
# Attack path this models:
#   internet -> :3306 / :5432 / :1433 reachable -> credential spray on a weak
#            password -> full data read, and no backup to recover from
#
# DO NOT APPLY.
###############################################################################

provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
}

# --- AWS: RDS published to the internet -------------------------------------
# Categories: Access Control, Encryption, Backup, Networking and Firewall

resource "aws_security_group" "db_open" {
  name        = "scenario-public-db-sg"
  description = "Database ports open to the internet"

  ingress {
    description = "MySQL from anywhere"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PostgreSQL from anywhere"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MSSQL from anywhere"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "public_mysql" {
  identifier        = "scenario-public-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.medium"
  allocated_storage = 20

  username = "admin"
  password = "Password123!"

  publicly_accessible     = true
  vpc_security_group_ids  = [aws_security_group.db_open.id]
  storage_encrypted       = false
  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true
  multi_az                = false

  iam_database_authentication_enabled = false
  performance_insights_enabled        = false
  enabled_cloudwatch_logs_exports     = []
}

# Aurora cluster, also public and unencrypted
resource "aws_rds_cluster" "public_aurora" {
  cluster_identifier      = "scenario-public-aurora"
  engine                  = "aurora-postgresql"
  master_username         = "admin"
  master_password         = "Password123!"
  storage_encrypted       = false
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
}

# Redis/ElastiCache without encryption or auth token
# Categories: Encryption, Access Control
resource "aws_elasticache_replication_group" "public_redis" {
  replication_group_id       = "scenario-public-redis"
  description                = "Unencrypted cache"
  node_type                  = "cache.t3.micro"
  engine                     = "redis"
  transit_encryption_enabled = false
  at_rest_encryption_enabled = false
}

# DocumentDB with TLS disabled via parameter group
resource "aws_docdb_cluster" "public_docdb" {
  cluster_identifier  = "scenario-public-docdb"
  master_username     = "admin"
  master_password     = "Password123!"
  storage_encrypted   = false
  skip_final_snapshot = true
  deletion_protection = false
}

# Snapshot shared with every AWS account on earth
# Category: Access Control
resource "aws_db_snapshot" "shared" {
  db_instance_identifier = aws_db_instance.public_mysql.identifier
  db_snapshot_identifier = "scenario-public-snapshot"
}

# --- Azure: SQL Server open to the world ------------------------------------
# Categories: Access Control, Encryption, Observability

resource "azurerm_resource_group" "db" {
  name     = "scenario-public-db-rg"
  location = "eastus"
}

resource "azurerm_mssql_server" "public" {
  name                = "scenario-public-sql"
  resource_group_name = azurerm_resource_group.db.name
  location            = azurerm_resource_group.db.location
  version             = "12.0"

  administrator_login          = "sqladmin"
  administrator_login_password = "Password123!"

  minimum_tls_version           = "1.0"
  public_network_access_enabled = true
}

# The classic "allow the entire IPv4 internet" firewall rule
resource "azurerm_mssql_firewall_rule" "the_whole_internet" {
  name             = "AllowTheWholeInternet"
  server_id        = azurerm_mssql_server.public.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

resource "azurerm_mssql_database" "public" {
  name      = "scenario-public-db"
  server_id = azurerm_mssql_server.public.id
  sku_name  = "S0"
  # No transparent data encryption block, no long-term retention policy
}

# PostgreSQL flexible server with SSL not enforced and public access
resource "azurerm_postgresql_flexible_server" "public" {
  name                          = "scenario-public-pg"
  resource_group_name           = azurerm_resource_group.db.name
  location                      = azurerm_resource_group.db.location
  version                       = "14"
  administrator_login           = "pgadmin"
  administrator_password        = "Password123!"
  storage_mb                    = 32768
  sku_name                      = "B_Standard_B1ms"
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = true
}

# Cosmos DB reachable from any network
resource "azurerm_cosmosdb_account" "public" {
  name                = "scenario-public-cosmos"
  resource_group_name = azurerm_resource_group.db.name
  location            = azurerm_resource_group.db.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  public_network_access_enabled     = true
  is_virtual_network_filter_enabled = false
  local_authentication_disabled     = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.db.location
    failover_priority = 0
  }
}
