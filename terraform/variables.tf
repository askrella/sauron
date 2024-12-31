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