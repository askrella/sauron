resource "docker_image" "caddy" {
  name         = "caddy:2.9"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "caddy" {
  name  = "caddy-${var.index}"
  image = docker_image.caddy.image_id

  restart = "unless-stopped"

  env = [
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-${var.index}:4317",
    "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://otel-${var.index}:4317",
    "OTEL_EXPORTER_OTLP_INSECURE=true",
    "OTEL_SERVICE_NAME=caddy-${var.index}"
  ]

  ports {
    internal = 80
    external = 80
    protocol = "tcp"
    ip       = "::"
  }

  ports {
    internal = 443
    external = 443
    protocol = "tcp"
    ip       = "::"
  }

  ports {
    internal = 2053
    external = 2053
    protocol = "tcp"
    ip       = "::"
  }

  ports {
    internal = 2083
    external = 2083
    protocol = "tcp"
    ip       = "::"
  }

  volumes {
    container_path = "/etc/caddy/Caddyfile"
    host_path      = local.caddyfile_path
    read_only      = true
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.working_dir}/caddy/data"
  }

  volumes {
    container_path = "/config"
    host_path      = "${local.working_dir}/caddy/config"
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
  }

  depends_on = [
    docker_container.grafana,
    docker_container.otel,
    null_resource.caddy_config
  ]

  healthcheck {
    test         = ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/api/health"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
  
  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]

    replace_triggered_by = [
      null_resource.caddy_configs
    ]
  }
}
