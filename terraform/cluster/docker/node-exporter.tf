
resource "docker_image" "node_exporter" {
  name = "prom/node-exporter:latest"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "node_exporter" {
  name  = "node-exporter-${var.index}"
  image = docker_image.node_exporter.image_id

  restart = "no"

  ports {
    internal = 9100
    external = var.node_exporter_port
    protocol = "tcp"
  }

  volumes {
    container_path = "/host/proc"
    host_path      = "/proc"
    read_only      = true
  }

  volumes {
    container_path = "/host/sys"
    host_path      = "/sys"
    read_only      = true
  }

  volumes {
    container_path = "/rootfs"
    host_path      = "/"
    read_only      = true
  }

  command = [
    "--path.procfs=/host/proc",
    "--path.rootfs=/rootfs",
    "--path.sysfs=/host/sys",
    "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
  ]

  depends_on = [null_resource.docker_network]

  networks_advanced {
    name = docker_network.monitoring.name
  }
}
