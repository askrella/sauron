resource "docker_image" "alloy" {
  name         = "grafana/alloy:v1.9.2"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "alloy" {
  name  = "alloy-${var.index}"
  image = docker_image.alloy.image_id

  restart = "unless-stopped"

  ports {
    internal = 4317
    external = 4317
    protocol = "tcp"
    ip = "0.0.0.0"
  }

  ports {
    internal = 4318
    external = 4318
    protocol = "tcp"
    ip = "0.0.0.0"
  }

  volumes {
    container_path = "/etc/loki/local-config.yaml"
    host_path      = local.alloy_config_path
    read_only      = true
  }

  command = [
    "run",
    "--storage.path=/var/lib/alloy/data",
    "--disable-reporting",
    "--stability.level=experimental",
    "/etc/loki/local-config.yaml"
  ]

  networks_advanced {
    name = docker_network.monitoring.name
  }

  depends_on = [
    null_resource.alloy_configs
  ]

  healthcheck {
    test         = ["CMD-SHELL", "bash -c 'exec 42<>/dev/tcp/localhost/12345 && echo -e 'GET /-/ready HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n' >&42 && head -1 <&42 | cut -d' ' -f2 | grep -q '^200$' || exit 1 && exec 42<&- && exec 42>&-'"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
  
  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]

    replace_triggered_by = [
      null_resource.alloy_configs
    ]
  }
}
