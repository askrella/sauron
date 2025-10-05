variable "cadvisor_version" {
  type        = string
  default     = "v0.52.0"
  description = "The version of cAdvisor to use"
}

variable "prometheus_version" {
  type        = string
  default     = "v3.6.0"
  description = "The version of Prometheus to use"
}

variable "promtail_version" {
  type        = string
  default     = "3.5.5"
  description = "The version of Promtail to use"
}

variable "alloy_image" {
  type = string
  default = "grafana/alloy:v1.11.0"
  description = "The alloy image to use" # We sometimes use dev versions due to changes we contributed to Alloy
}

variable "grafana_version" {
  type        = string
  default     = "12.2.0"
  description = "The version of Grafana to use"
}

variable "tempo_version" {
  type        = string
  default     = "2.8.2"
  description = "The version of Tempo to use"
}

variable "loki_version" {
  type        = string
  default     = "3.5.5"
  description = "The version of Loki to use"
}

variable "caddy_version" {
  type = string
  default = "2.10.2"
  description = "The Caddy version to use"
}

variable "mariadb_galera_version" {
  type = string
  default = "11.4.4"
  description = "The Mariadb Galera version to use"
}

variable "node_exporter_version" {
  type = string
  default = "v1.9.1"
  description = "The Node Exporter version to use"
}

