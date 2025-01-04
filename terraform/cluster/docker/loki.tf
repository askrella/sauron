locals {
  node_count = length(var.cluster_ipv4_addresses)
}

resource "docker_image" "loki" {
  name         = "grafana/loki:${var.loki_version}"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "loki" {
  name  = "loki-${var.index}"
  image = docker_image.loki.image_id

  restart = "unless-stopped"

  ports {
    internal = 3100
    external = 3100
    protocol = "tcp"
  }

  ports {
    internal = 7946
    external = 7946
    protocol = "tcp"
  }

  ports {
    internal = 9095
    external = 9095
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/loki/config.yaml"
    host_path      = local.loki_config_file_path
    read_only      = true
  }

  volumes {
    container_path = "/loki"
    host_path      = local.loki_data_dir
  }

  volumes {
    container_path = "/etc/gai.conf"
    host_path      = "${local.working_dir}/etc/gai.conf"
    read_only      = true
  }

  command = [
    "--config.file=/etc/loki/config.yaml"
  ]

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
  }

  depends_on = [
    null_resource.data_collectors_up,
    null_resource.loki_configs
  ]

  dns = [
    "fedc::1",              # Docker DNS
    "2606:4700:4700::1111", # Cloudflare DNS
    "2606:4700:4700::1001"  # Cloudflare DNS fallback
  ]

  user = "10001"

  healthcheck {
    test         = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]
  }
}
