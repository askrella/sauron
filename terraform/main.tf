terraform {
  required_version = ">= v1.10.3"

  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.49.1"
    }
    minio = {
      source = "aminueza/minio"
      version = "3.2.2"
    }
  }
}

variable "hcloud_token" {
  sensitive = true
}

variable "cluster_size" {
  type = number
  default = 1
}

variable "gf_server_root_url" {
  type = string
  description = "The root URL for Grafana"
}

variable "gf_auth_google_client_id" {
  type = string
  description = "Google OAuth client ID"
}

variable "gf_auth_google_client_secret" {
  type = string
  description = "Google OAuth client secret"
  sensitive = true
}

variable "gf_auth_google_allowed_domains" {
  type = string
  description = "Allowed domains for Google OAuth"
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

variable "minio_user" {
  type = string
  description = "The MinIO user"
}

variable "minio_password" {
  type = string
  description = "The MinIO password"
  sensitive = true
}

variable "minio_bucket" {
  type = string
  description = "The MinIO bucket name"
}

variable "minio_region" {
  type = string
  description = "The MinIO region"
}

provider "minio" {
  minio_server   = "${var.minio_region}.your-objectstorage.com"
  minio_user     = var.minio_user
  minio_password = var.minio_password
  minio_region   = var.minio_region
  minio_ssl      = true
}

resource "minio_s3_bucket" "bucket" {
  bucket         = var.minio_bucket
  acl            = "private"
  object_locking = false
}

module "server" {
    source = "./hetzner_server"
    hcloud_token = var.hcloud_token
    cluster_name = "test"
    server_count = var.cluster_size
    server_prefix = "server"
}

module "cluster" {
  source = "./cluster"
  server_ipv6_addresses = module.server.server_ipv6_addresses
  server_ipv4_addresses = module.server.server_ipv4_addresses
  ssh_absolute_key_path = "${abspath("./id_ed25519")}"
  cluster_size = var.cluster_size

  minio_bucket = var.minio_bucket
  minio_user = var.minio_user
  minio_password = var.minio_password
  minio_region = var.minio_region

  grafana_admin_password = var.grafana_admin_password

  gf_server_root_url = var.gf_server_root_url
  gf_auth_google_client_id = var.gf_auth_google_client_id
  gf_auth_google_client_secret = var.gf_auth_google_client_secret
  gf_auth_google_allowed_domains = var.gf_auth_google_allowed_domains

  depends_on = [module.server, minio_s3_bucket.bucket]
}