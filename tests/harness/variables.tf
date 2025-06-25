variable "is_local_test_environment" {
  description = "If true, enables self-signed TLS, local networking, and disables public DNS dependencies."
  type        = bool
  default     = false
}

variable "cluster_size" {
  description = "The number of nodes in the test cluster."
  type        = number
  default     = 1
}

variable "domain" {
  description = "The domain for testing purposes."
  type        = string
  default     = "test.local"
}

variable "minio_bucket" {
  type    = string
  default = "test-bucket"
}

variable "minio_user" {
  type    = string
  default = "test-user"
}

variable "minio_password" {
  type      = string
  default   = "test-password"
  sensitive = true
}

variable "minio_region" {
  type    = string
  default = "us-east-1"
}

variable "grafana_admin_password" {
  type      = string
  default   = "admin"
  sensitive = true
}

variable "otel_collector_username" {
  type    = string
  default = "otel"
}

variable "otel_collector_password" {
  type      = string
  default   = "otel"
  sensitive = true
}

variable "gf_server_root_url" {
  type    = string
  default = "https://grafana.test.local"
}

variable "gf_auth_google_client_id" {
  type    = string
  default = "dummy"
}

variable "gf_auth_google_client_secret" {
  type      = string
  default   = "dummy"
  sensitive = true
}

variable "gf_auth_google_allowed_domains" {
  type    = string
  default = "example.com"
}

variable "mariadb_root_password" {
  type      = string
  default   = "rootpassword"
  sensitive = true
}

variable "mariadb_backup_password" {
  type      = string
  default   = "backuppassword"
  sensitive = true
}

variable "mariadb_database" {
  type    = string
  default = "testdb"
}

variable "mariadb_user" {
  type    = string
  default = "testuser"
}

variable "mariadb_password" {
  type      = string
  default   = "testpassword"
  sensitive = true
} 