variable "tempo_version" {
  type        = string
  default     = "2.6.1"
  description = "The version of Tempo to use"
}

variable "tempo_port" {
  type        = number
  default     = 3200
  description = "The port to expose Tempo on"
}

resource "docker_image" "tempo" {
  name         = "grafana/tempo:${var.tempo_version}"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "tempo" {
  name  = "tempo-${var.index}"
  image = docker_image.tempo.image_id

  restart = "unless-stopped"

  ports {
    internal = 3200
    external = var.tempo_port
    protocol = "tcp"
  }

  ports {
    internal = 7946
    external = 7956
    protocol = "tcp"
  }

  ports {
    internal = 4417
    external = 4417
    protocol = "tcp"
  }

  ports {
    internal = 4418
    external = 4418
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/tempo/config.yaml"
    host_path      = local.tempo_config_file_path
    read_only      = true
  }

  volumes {
    container_path = "/tmp/tempo"
    host_path      = local.tempo_data_dir
    read_only      = false
  }

  command = [
    "-config.file=/etc/tempo/config.yaml"
  ]

  security_opts = [
    "no-new-privileges:true"
  ]

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
  }

  user = "65534" # nobody user

  healthcheck {
    test         = ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3200/ready"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  depends_on = [
    null_resource.docker_network,
    null_resource.tempo_configs
  ]

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]

    replace_triggered_by = [
      null_resource.tempo_configs
    ]
  }
}
