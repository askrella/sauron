terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_network" "monitoring_net" {
  name = "monitoring_net"
}

module "cluster" {
  source = "../../terraform/cluster"

  # Pass through all the variables needed by the cluster module.
  # The dummy defaults are defined in variables.tf.
  is_local_test_environment = var.is_local_test_environment
  cluster_size                = var.cluster_size
  domain                      = var.domain

  # These are not used in local testing mode, but the module expects them.
  # We provide empty lists or dummy values.
  server_ipv6_addresses = []
  server_ipv4_addresses = []
  ssh_absolute_key_path = "" # Not used in local mode

  minio_bucket   = var.minio_bucket
  minio_user     = var.minio_user
  minio_password = var.minio_password
  minio_region   = var.minio_region

  grafana_admin_password = var.grafana_admin_password

  otel_collector_username = var.otel_collector_username
  otel_collector_password = var.otel_collector_password

  gf_server_root_url             = var.gf_server_root_url
  gf_auth_google_client_id       = var.gf_auth_google_client_id
  gf_auth_google_client_secret   = var.gf_auth_google_client_secret
  gf_auth_google_allowed_domains = var.gf_auth_google_allowed_domains

  mariadb_root_password   = var.mariadb_root_password
  mariadb_backup_password = var.mariadb_backup_password
  mariadb_database        = var.mariadb_database
  mariadb_user            = var.mariadb_user
  mariadb_password        = var.mariadb_password
} 