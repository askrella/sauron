terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

locals {
  working_dir = "/home/docker"
}

variable "domain" {
  type        = string
  description = "The domain name used for accessing the cluster: monitoring.example.com"
}

variable "index" {
  type        = number
  description = "The index of the server in the cluster"
}

variable "server_ipv6_address" {
  type        = string
  description = "The IPv6 address of the server"

  validation {
    condition     = can(regex("^[0-9a-fA-F:]+$", var.server_ipv6_address))
    error_message = "Invalid IPv6 address format."
  }
}

variable "cluster_ipv6_addresses" {
  type        = list(string)
  description = "The IPv6 addresses of all the nodes in the cluster (possibly including the current node)"
}

variable "cluster_ipv4_addresses" {
  type        = list(string)
  description = "The IPv4 addresses of all the nodes in the cluster (possibly including the current node)"
}

variable "ssh_key_path" {
  type        = string
  description = "The path to the SSH key to use for the Docker provider"
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

variable "minio_bucket" {
  type        = string
  description = "The MinIO bucket name"
}

locals {
  minio_endpoint = "${var.minio_region}.your-objectstorage.com"
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

variable "minio_region" {
  type        = string
  description = "The MinIO region"
}

variable "loki_version" {
  type        = string
  default     = "3.3.2"
  description = "The version of Loki to use"
}

variable "promtail_version" {
  type        = string
  default     = "3.3.2"
  description = "The version of Promtail to use"
}

variable "node_exporter_port" {
  type        = number
  default     = 9100
  description = "The port to expose Node Exporter on"
}

variable "prometheus_version" {
  type        = string
  default     = "v3.1.0-rc.1"
  description = "The version of Prometheus to use"
}

variable "prometheus_port" {
  type        = number
  default     = 9090
  description = "The port to expose Prometheus on"
}

variable "cadvisor_version" {
  type        = string
  default     = "v0.49.2"
  description = "The version of cAdvisor to use"
}

variable "cadvisor_port" {
  type        = number
  default     = 8080
  description = "The port to expose cAdvisor on"
}

variable "grafana_version" {
  type        = string
  default     = "11.4.0"
  description = "The version of Grafana to use"
}

variable "grafana_port" {
  type        = number
  default     = 3000
  description = "The port to expose Grafana on"
}

variable "gf_server_root_url" {
  type        = string
  description = "Grafana server root URL"
}

variable "gf_auth_google_enabled" {
  type        = string
  description = "Enable Google OAuth"
}

variable "gf_auth_google_name" {
  type        = string
  description = "Google OAuth name"
}

variable "gf_auth_google_client_id" {
  type        = string
  description = "Google OAuth client ID"
}

variable "gf_auth_google_client_secret" {
  type        = string
  description = "Google OAuth client secret"
}

variable "gf_auth_google_scopes" {
  type        = string
  description = "Google OAuth scopes"
}

variable "gf_auth_google_auth_url" {
  type        = string
  description = "Google OAuth auth URL"
}

variable "gf_auth_google_token_url" {
  type        = string
  description = "Google OAuth token URL"
}

variable "gf_auth_google_api_url" {
  type        = string
  description = "Google OAuth API URL"
}

variable "gf_auth_google_allowed_domains" {
  type        = string
  description = "Google OAuth allowed domains"
}

variable "gf_auth_google_allow_sign_up" {
  type        = string
  description = "Allow sign up through Google OAuth"
}

variable "mariadb_root_password" {
  type        = string
  description = "The root password for MariaDB"
  sensitive   = true
}

variable "mariadb_database" {
  type        = string
  description = "The name of the MariaDB database to create"
}

variable "mariadb_user" {
  type        = string
  description = "The name of the MariaDB user to create"
}

variable "mariadb_password" {
  type        = string
  description = "The password for the MariaDB user"
  sensitive   = true
}

variable "mariadb_backup_password" {
  type        = string
  description = "The password for the MariaDB backup user"
  sensitive   = true
}

locals {
  # Get all server IPs except our own for Thanos Query to connect to other sidecars
  other_server_ips = [
    for i, ip in var.cluster_ipv4_addresses : ip
    if i != var.index
  ]
}

provider "docker" {
  host = "ssh://root@${var.server_ipv6_address}:22"
  ssh_opts = [
    "-vvv",
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null",
    "-o", "ConnectTimeout=10",
    "-o", "ConnectionAttempts=3",
    "-o", "BatchMode=no",
    "-o", "LogLevel=INFO",
    "-i", var.ssh_key_path,
  ]
}

resource "null_resource" "ssh_check" {
  provisioner "remote-exec" {
    inline = [
      "echo 'SSH connection test in separate invoke successful to ${var.server_ipv6_address} with index ${var.index}'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    always = timestamp()
  }
}

resource "null_resource" "healthcheck_container" {
  provisioner "remote-exec" {
    inline = [
      "docker run --rm hello-world"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  depends_on = [
    docker_image.hello_world,
    null_resource.ssh_check,
    null_resource.setup_directories
  ]
}

resource "docker_image" "hello_world" {
  name         = "hello-world:latest"
  keep_locally = false

  depends_on = [
    null_resource.ssh_check
  ]
}

locals {
  grafana_user        = "472"
  grafana_plugins_dir = "${local.working_dir}/grafana/config/plugins"
  setup_directories_inline = [
      "touch /var/log/audit/audit.log",
      "mkdir -p ${local.working_dir}",
      "mkdir -p ${local.working_dir}/mariadb",
      "mkdir -p ${local.working_dir}/mariadb/data",
      "mkdir -p ${local.working_dir}/mariadb/backup",
      "chown -R 1001:1001 ${local.working_dir}/mariadb",
      "mkdir -p ${local.working_dir}/grafana/config/dashboards",
      "mkdir -p ${local.grafana_plugins_dir}",
      "mkdir -p ${local.working_dir}/grafana/config/provisioning/datasources",
      "mkdir -p ${local.working_dir}/grafana/config/provisioning/alerting",
      "mkdir -p ${local.working_dir}/grafana/data",
      "mkdir -p ${local.working_dir}/prometheus/config",
      "mkdir -p ${local.working_dir}/prometheus/data",
      "mkdir -p ${local.working_dir}/thanos/sidecar/config",
      "mkdir -p ${local.working_dir}/thanos/ruler",
      "mkdir -p ${local.working_dir}/thanos/ruler/config",
      "mkdir -p ${local.working_dir}/thanos/store",
      "mkdir -p ${local.working_dir}/thanos/store/config",
      "mkdir -p ${local.working_dir}/thanos/compactor",
      "mkdir -p ${local.working_dir}/thanos/compactor/config",
      "mkdir -p ${local.working_dir}/loki/config",
      "mkdir -p ${local.working_dir}/loki/data",
      "mkdir -p ${local.working_dir}/promtail/config",
      "mkdir -p ${local.working_dir}/promtail/positions",
      "mkdir -p ${local.working_dir}/etc",
      "mkdir -p ${local.working_dir}/alloy",
      "mkdir -p ${local.working_dir}/alloy/config",
      "mkdir -p ${local.working_dir}/otel",
      "mkdir -p ${local.working_dir}/otel/config",
      "mkdir -p ${local.working_dir}/caddy",
      "mkdir -p ${local.working_dir}/caddy/data",
      "mkdir -p ${local.working_dir}/caddy/config",
      "mkdir -p ${local.working_dir}/caddy/config",
      "echo '# Custom configuration to prefer IPv6 over IPv4\nprecedence ::/0  100\nprecedence ::ffff:0:0/96  10' > ${local.working_dir}/etc/gai.conf",
      "chown -R ${local.grafana_user}:${local.grafana_user} ${local.working_dir}/grafana", # Grafana user
      "chown -R 65534:65534 ${local.working_dir}/prometheus",                              # nobody user
      "chown -R 10001:10001 ${local.working_dir}/loki",                                    # loki user
      "chown -R 65534:65534 ${local.working_dir}/thanos"                                   # nobody user for Thanos
    ]
}

resource "null_resource" "setup_directories" {
  provisioner "remote-exec" {
    inline = local.setup_directories_inline

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    inline = join("\n", local.setup_directories_inline)
  }
}
