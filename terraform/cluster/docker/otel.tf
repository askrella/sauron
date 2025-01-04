variable "otel_version" {
  type        = string
  default     = "0.116.1"
  description = "The version of OpenTelemetry Collector to use"
}

# Create the OpenTelemetry configuration file
resource "null_resource" "otel_config" {
  provisioner "file" {
    content = templatefile("${path.module}/otel/config.yml", {
      index = var.index
    })
    destination = "${local.working_dir}/otel/config/config.yml"

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

resource "docker_image" "otel" {
  name         = "otel/opentelemetry-collector-contrib:${var.otel_version}"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "otel" {
  name  = "otel-${var.index}"
  image = docker_image.otel.image_id

  restart = "unless-stopped"

  ports {
    internal = 4317
    external = 4317
    protocol = "tcp"
  }

  ports {
    internal = 4318
    external = 4318
    protocol = "tcp"
  }

  ports {
    internal = 8889
    external = 8889
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/otelcol/config.yml"
    host_path      = "${local.working_dir}/otel/config/config.yml"
    read_only      = true
  }

  command = [
    "--config=/etc/otelcol/config.yml"
  ]

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
  }

  healthcheck {
    test         = ["CMD", "/bin/sh", "-c", "wget --no-verbose --tries=1 --spider http://localhost:4318/health/status"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  depends_on = [
    null_resource.docker_network,
    null_resource.otel_config,
    docker_container.tempo
  ]

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]
  }
}
