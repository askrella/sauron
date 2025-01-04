variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_logout_redirect_url" {
  description = "URL to redirect to after logout"
  type        = string
  default     = ""
}

variable "otel_collector_username" {
  description = "The username for the OTel collector"
  type        = string
}

variable "otel_collector_password" {
  description = "The bcrypt hashed password for the OTel collector"
  type        = string
  sensitive   = true
}

variable "hcloud_token" {
  type        = string
  sensitive = true
}

variable "cluster_size" {
  description = "The number of nodes in the cluster"
  type    = number
  default = 1
}

variable "domain" {
  type        = string
  description = "The domain name to create the load balancer for, example: monitoring.example.com"
}

variable "base_domain" {
  type        = string
  description = "The base domain name to create the load balancer for, example: example.com"
}

variable "cloudflare_api_token" {
  type        = string
  description = "The API token for the Cloudflare account"
  sensitive   = true
}

variable "cloudflare_account_id" {
  type        = string
  description = "The account ID for the Cloudflare account"
}

variable "gf_server_root_url" {
  type        = string
  description = "The root URL for Grafana"
}

variable "gf_auth_google_client_id" {
  type        = string
  description = "Google OAuth client ID"
}

variable "gf_auth_google_client_secret" {
  type        = string
  description = "Google OAuth client secret"
  sensitive   = true
}

variable "gf_auth_google_allowed_domains" {
  type        = string
  description = "Allowed domains for Google OAuth"
}

variable "minio_user" {
  type        = string
  description = "The MinIO user"
}

variable "minio_password" {
  type        = string
  description = "The MinIO password"
  sensitive   = true
}

variable "minio_bucket" {
  type        = string
  description = "The MinIO bucket name"
}

variable "minio_region" {
  type        = string
  description = "The MinIO region"
}

resource "minio_s3_bucket" "bucket" {
  bucket         = var.minio_bucket
  acl            = "private"
  object_locking = false
}
