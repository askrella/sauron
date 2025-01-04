locals {
  thanos_sidecar_label = "thanos-sidecar-${var.index}"
}

resource "docker_container" "thanos_sidecar" {
  name  = "thanos-sidecar-${var.index}"
  image = docker_image.thanos.image_id

  labels {
    label = "pod"
    value = local.thanos_sidecar_label
  }

  command = [
    "sidecar",
    "--objstore.config-file=/etc/thanos/sidecar.yaml",
    "--tsdb.path=/prometheus/data",
    "--log.level=debug",
    "--prometheus.url=http://prometheus-${var.index}:9090",
    "--http-address=0.0.0.0:10902",
    "--grpc-address=0.0.0.0:10901"
  ]

  ports {
    internal = 10901
    external = 10901
    protocol = "tcp"
  }

  ports {
    internal = 10902
    external = 10902
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/thanos/sidecar.yaml"
    host_path      = local.thanos_sidecar_config_file_path
    read_only      = true
  }

  volumes {
    container_path = "/prometheus"
    host_path      = local.thanos_sidecar_data_dir
    read_only      = false
  }

  healthcheck {
    test         = ["CMD", "wget", "--spider", "http://localhost:10902/-/healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
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
    docker_container.prometheus,
    null_resource.setup_directories,
    null_resource.thanos_sidecar_configs
  ]

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]
  }
}
