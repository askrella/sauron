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

resource "docker_image" "grafana" {
  name          = "grafana/grafana:${var.grafana_version}"
  pull_triggers = [var.grafana_version]
  platform      = "linux/arm64"
  keep_locally  = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "grafana" {
  name  = "grafana-${var.index}"
  image = docker_image.grafana.image_id

  restart = "unless-stopped"

  ports {
    internal = 3000
    external = var.grafana_port
    protocol = "tcp"
    ip       = "::"
  }

  volumes {
    container_path = "/var/lib/grafana"
    host_path      = "${local.working_dir}/grafana/data"
    read_only      = false
  }

  volumes {
    container_path = "/etc/grafana/grafana.ini"
    host_path      = local.grafana_ini_path
    read_only      = true
  }

  volumes {
    container_path = "/etc/grafana/provisioning/alerting"
    host_path      = "${local.working_dir}/grafana/config/provisioning/alerting"
    read_only      = true
  }

  volumes {
    container_path = "/etc/grafana/provisioning/datasources"
    host_path      = local.grafana_datasources_path_dir
    read_only      = true
  }

  volumes {
    container_path = "/etc/grafana/provisioning/dashboards"
    host_path      = local.grafana_dashboards_path_dir
    read_only      = true
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
  }

  depends_on = [
    null_resource.databases_up,
    null_resource.grafana_configs
  ]

  user = local.grafana_user

  dns = [
    "fedc::1",              # Docker DNS
    "2606:4700:4700::1111", # Cloudflare DNS
    "2606:4700:4700::1001"  # Cloudflare DNS fallback
  ]

  env = [
    "GF_AUTH_BASIC_ENABLED=false",
    "GF_SERVER_ROOT_URL=${var.gf_server_root_url}",
    "GF_AUTH_GOOGLE_ENABLED=${var.gf_auth_google_enabled}",
    "GF_AUTH_GOOGLE_NAME=${var.gf_auth_google_name}",
    "GF_AUTH_GOOGLE_CLIENT_ID=${var.gf_auth_google_client_id}",
    "GF_AUTH_GOOGLE_CLIENT_SECRET=${var.gf_auth_google_client_secret}",
    "GF_AUTH_GOOGLE_SCOPES=${var.gf_auth_google_scopes}",
    "GF_AUTH_GOOGLE_AUTH_URL=${var.gf_auth_google_auth_url}",
    "GF_AUTH_GOOGLE_TOKEN_URL=${var.gf_auth_google_token_url}",
    "GF_AUTH_GOOGLE_API_URL=${var.gf_auth_google_api_url}",
    "GF_AUTH_GOOGLE_ALLOWED_DOMAINS=${var.gf_auth_google_allowed_domains}",
    "GF_AUTH_GOOGLE_ALLOW_SIGN_UP=${var.gf_auth_google_allow_sign_up}",
    "GF_AUTH_GOOGLE_USE_PKCE=true",
    "GF_AUTH_GOOGLE_AUTO_LOGIN=false",
    "GF_SECURITY_ADMIN_USER=${var.grafana_admin_user}",
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}",
    "GF_AUTH_LOGOUT_REDIRECT_URL=${var.grafana_logout_redirect_url}",

    # Database configuration
    "GF_DATABASE_TYPE=mysql",
    "GF_DATABASE_HOST=mariadb-${var.index}:3306",
    "GF_DATABASE_NAME=${var.mariadb_database}",
    "GF_DATABASE_USER=${var.mariadb_user}",
    "GF_DATABASE_PASSWORD=${var.mariadb_password}",
    "GF_DATABASE_MAX_OPEN_CONN=100",
    "GF_DATABASE_MAX_IDLE_CONN=100",
    "GF_DATABASE_CONN_MAX_LIFETIME=14400",

    # Provisioning data sources
    "GF_INSTALL_PLUGINS=https://storage.googleapis.com/integration-artifacts/grafana-exploretraces-app/grafana-exploretraces-app-latest.zip;grafana-traces-app",
    "GF_PATHS_PROVISIONING=/etc/grafana/provisioning",
    "GF_DATASOURCES_PATH=/etc/grafana/provisioning/datasources"
  ]

  memory      = 700  // MB
  memory_swap = 1024 // MB
  cpu_shares  = 512

  healthcheck {
    test         = ["CMD", "wget", "--spider", "http://localhost:3000"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]

    replace_triggered_by = [
      null_resource.grafana_configs
    ]
  }
}

