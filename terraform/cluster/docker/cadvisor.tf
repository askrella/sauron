resource "docker_image" "cadvisor" {
  name = "gcr.io/cadvisor/cadvisor:${var.cadvisor_version}"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "cadvisor" {
  name  = "cadvisor-${var.index}"
  image = docker_image.cadvisor.image_id

  restart = "unless-stopped"

  ports {
    internal = 8080
    external = var.cadvisor_port
    protocol = "tcp"
  }

  volumes {
    container_path = "/rootfs"
    host_path      = "/"
    read_only      = true
  }

  volumes {
    container_path = "/var/run"
    host_path      = "/var/run"
    read_only      = false
  }

  volumes {
    container_path = "/sys"
    host_path      = "/sys"
    read_only      = true
  }

  volumes {
    container_path = "/dev/kmsg"
    host_path      = "/dev/kmsg"
    read_only      = true
  }

  volumes {
    container_path = "/var/lib/docker"
    host_path      = "/var/lib/docker"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  depends_on = [null_resource.docker_network]
}
