terraform {
  required_version = ">= v1.10.3"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.49.1"
    }
    minio = {
      source  = "aminueza/minio"
      version = "3.2.2"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.51.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "minio" {
  minio_server   = "${var.minio_region}.your-objectstorage.com"
  minio_user     = var.minio_user
  minio_password = var.minio_password
  minio_region   = var.minio_region
  minio_ssl      = true
}

module "server" {
  source        = "./hetzner_server"
  hcloud_token  = var.hcloud_token
  cluster_name  = "test"
  server_count  = var.cluster_size
  server_prefix = "server"
}

module "cluster" {
  source                = "./cluster"
  server_ipv6_addresses = module.server.server_ipv6_addresses
  server_ipv4_addresses = module.server.server_ipv4_addresses
  ssh_absolute_key_path = abspath("./id_ed25519")
  cluster_size          = var.cluster_size
  domain                = var.domain

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

  mariadb_root_password = var.mariadb_root_password
  mariadb_backup_password = var.mariadb_backup_password
  mariadb_database      = var.mariadb_database
  mariadb_user          = var.mariadb_user
  mariadb_password      = var.mariadb_password

  depends_on = [module.server, minio_s3_bucket.bucket]
}

module "cloudflare" {
  source                = "./cloudflare"
  cloudflare_api_token  = var.cloudflare_api_token
  cloudflare_account_id = var.cloudflare_account_id
  domain                = var.domain
  base_domain           = var.base_domain
  ipv6_addresses        = module.server.server_ipv6_addresses
  depends_on            = [module.server]
}
