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

# Create the datasources configuration file
resource "null_resource" "grafana_datasources" {
  provisioner "file" {
    content = templatefile("${path.module}/grafana/config/provisioning/datasources/datasources.yaml", {
      bucket     = var.minio_bucket
      endpoint   = "${var.minio_region}.your-objectstorage.com"
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      index      = var.index
    })
    destination = "${local.working_dir}/grafana/config/provisioning/datasources/datasources.yaml"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    timestamp = timestamp()
  }

  depends_on = [null_resource.setup_directories]
}

locals {
  # Content not already covered by the environment variables
  grafana_ini_content = <<-EOT
EOT
}

# Add this resource after the grafana_config_dirs resource
resource "null_resource" "grafana_config_files" {
  provisioner "remote-exec" {
    inline = [
      "rm -rf ${local.working_dir}/grafana/config/grafana.ini",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  provisioner "file" {
    content     = local.grafana_ini_content
    destination = "${local.working_dir}/grafana/config/grafana.ini"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    grafana_ini_content = local.grafana_ini_content
    timestamp = timestamp()
  }

  depends_on = [null_resource.setup_directories]
}

resource "docker_image" "grafana" {
  name = "grafana/grafana:${var.grafana_version}"
  pull_triggers = [var.grafana_version]
  platform = "linux/arm64"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "grafana" {
  name = "grafana-${var.index}"
  image = docker_image.grafana.image_id

  restart = "unless-stopped"

  ports {
    internal = 3000
    external = var.grafana_port
    protocol = "tcp"
    ip = "::"
  }

  volumes {
    container_path = "/var/lib/grafana"
    host_path      = "${local.working_dir}/grafana/data"
    read_only      = false
  }

  volumes {
    container_path = "/etc/grafana/grafana.ini"
    host_path      = "${local.working_dir}/grafana/config/grafana.ini"
    read_only      = true
  }
  
  volumes {
    container_path = "/etc/grafana/provisioning/alerting"
    host_path      = "${local.working_dir}/grafana/config/provisioning/alerting"
    read_only      = true
  }

  volumes {
    container_path = "/etc/grafana/provisioning/datasources"
    host_path      = "${local.working_dir}/grafana/config/provisioning/datasources"
    read_only      = true
  }

  volumes {
    container_path = "/etc/grafana/provisioning/dashboards"
    host_path      = "${local.working_dir}/grafana/config/dashboards"
    read_only      = true
  }

  volumes {
    container_path = "${local.working_dir}/grafana/config/dashboards/dashboards.yaml"
    host_path      = "${local.working_dir}/grafana/config/dashboards/dashboards.yaml"
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
    null_resource.grafana_datasources,
    null_resource.grafana_config_files,
    null_resource.grafana_dashboards
  ]

  user = local.grafana_user

  dns = [
    "fedc::1", # Docker DNS
    "2606:4700:4700::1111", # Cloudflare DNS
    "2606:4700:4700::1001" # Cloudflare DNS fallback
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
    
    # Provisioning data sources
    "GF_INSTALL_PLUGINS=https://storage.googleapis.com/integration-artifacts/grafana-exploretraces-app/grafana-exploretraces-app-latest.zip;grafana-traces-app",
    "GF_PATHS_PROVISIONING=/etc/grafana/provisioning",
    "GF_DATASOURCES_PATH=/etc/grafana/provisioning/datasources"
  ]

  memory    = 700  // MB
  memory_swap = 1024  // MB
  cpu_shares = 512

  healthcheck {
    test = ["CMD", "wget", "--spider", "http://localhost:3000"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
    start_period = "30s"
  }
}

# Add after grafana_config_dirs resource
resource "null_resource" "grafana_dashboards" {

  provisioner "file" {
    content = <<-EOT
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
    EOT
    destination = "${local.working_dir}/grafana/config/dashboards/dashboards.yaml"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  provisioner "file" {
    source      = "${path.module}/grafana/config/dashboards/cAdvisor.json"
    destination = "${local.working_dir}/grafana/config/dashboards/cAdvisor.json"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  provisioner "file" {
    source      = "${path.module}/grafana/config/dashboards/node-exporter.json"
    destination = "${local.working_dir}/grafana/config/dashboards/node-exporter.json"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  provisioner "file" {
    source      = "${path.module}/grafana/config/dashboards/thanos.json"
    destination = "${local.working_dir}/grafana/config/dashboards/thanos.json"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  provisioner "file" {
    content     = templatefile("${path.module}/grafana/config/dashboards/askrella-loki.json", {
      required_loki_nodes = local.node_count >= 3 ? 3 : local.node_count
    })
    destination = "${local.working_dir}/grafana/config/dashboards/askrella-loki.json"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    timestamp = timestamp()
  }

  depends_on = [null_resource.setup_directories]
}
