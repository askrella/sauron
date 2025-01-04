resource "docker_image" "prometheus" {
  name         = "prom/prometheus:${var.prometheus_version}"
  keep_locally = true

  depends_on = [
    null_resource.docker_network
  ]
}

resource "docker_container" "prometheus" {
  name  = "prometheus-${var.index}"
  image = docker_image.prometheus.image_id

  restart = "unless-stopped"

  ports {
    internal = 9090
    external = var.prometheus_port
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/prometheus"
    host_path      = local.prometheus_config_path_dir
    read_only      = false
  }

  volumes {
    container_path = "/prometheus"
    host_path      = local.prometheus_data_dir
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--enable-feature=expand-external-labels",
    "--storage.tsdb.wal-compression",
    "--web.enable-lifecycle", # Allows Prometheus to reload its configuration
    "--web.enable-admin-api",
    "--storage.tsdb.min-block-duration=2h",
    "--storage.tsdb.max-block-duration=2h",
    "--storage.tsdb.retention.time=48h"
  ]

  healthcheck {
    test         = ["CMD", "wget", "--spider", "http://localhost:9090/-/healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  user = "65534" # nobody user

  log_opts = {
    max-size = "10m"
    max-file = "3"
  }

  security_opts = [
    "no-new-privileges:true"
  ]

  depends_on = [
    null_resource.data_collectors_up,
    null_resource.prometheus_configs,
    null_resource.setup_directories
  ]

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]
  }
}
