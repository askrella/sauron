locals {
  thanos_store_gateway_label = "thanos-store-${var.index}"
}

resource "docker_container" "thanos_store" {
  name  = "thanos-store-${var.index}"
  image = docker_image.thanos.image_id

  restart = "unless-stopped"

  labels {
    label = "pod"
    value = local.thanos_store_gateway_label
  }

  command = [
    "store",
    "--objstore.config-file=/etc/thanos/store.yaml",
    "--http-address=0.0.0.0:10906",
    "--grpc-address=0.0.0.0:10905",
    "--data-dir=/data"
  ]

  ports {
    internal = 10905
    external = 10905
    protocol = "tcp"
  }

  ports {
    internal = 10906
    external = 10906
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/thanos/store.yaml"
    host_path      = local.thanos_store_gateway_config_file_path
    read_only      = true
  }

  volumes {
    container_path = "/data"
    host_path      = local.thanos_store_gateway_data_dir
    read_only      = false
  }

  healthcheck {
    test         = ["CMD", "wget", "--spider", "http://localhost:10906/-/healthy"]
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
    docker_image.thanos,
    null_resource.setup_directories,
    null_resource.thanos_store_gateway_configs
  ]

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]
  }
}
