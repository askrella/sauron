resource "docker_image" "promtail" {
  name         = "grafana/promtail:${var.promtail_version}"
  keep_locally = true

  depends_on = [
    null_resource.docker_network,
    null_resource.promtail_configs
  ]
}

resource "docker_container" "promtail" {
  name  = "promtail-${var.index}"
  image = docker_image.promtail.image_id

  restart = "unless-stopped"

  volumes {
    container_path = "/var/log"
    host_path      = "/var/log"
    read_only      = true
  }

  volumes {
    container_path = "/etc/promtail/config.yaml"
    host_path      = local.promtail_config_file_path
    read_only      = true
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    container_path = "/var/log/audit"
    host_path      = "/var/log/audit"
    read_only      = true
  }

  volumes {
    container_path = "/var/promtail-positions"
    host_path      = local.promtail_positions_dir
  }

  command = [
    "--config.file=/etc/promtail/config.yaml"
  ]

  networks_advanced {
    name = docker_network.monitoring.name
  }

  depends_on = [
    null_resource.docker_network,
    null_resource.promtail_configs
  ]

  healthcheck {
    test         = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9080/ready || exit 1"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]

    replace_triggered_by = [
      null_resource.promtail_configs
    ]
  }
}
