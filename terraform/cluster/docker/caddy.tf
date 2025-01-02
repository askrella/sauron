resource "docker_image" "caddy" {
  name         = "caddy:2.9"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

# Create the Caddy configuration file
resource "null_resource" "caddy_config" {
  provisioner "file" {
    content     = templatefile("${path.module}/caddy/Caddyfile", {
      domain  = var.domain
      node_id = var.index
    })
    destination = "${local.working_dir}/caddy/Caddyfile"

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

resource "docker_container" "caddy" {
  name  = "caddy-${var.index}"
  image = docker_image.caddy.image_id

  restart = "unless-stopped"

  ports {
    internal = 80
    external = 80
    protocol = "tcp"
    ip       = "::"
  }

  ports {
    internal = 443
    external = 443
    protocol = "tcp"
    ip       = "::"
  }

  ports {
    internal = 4317
    external = 4317
    protocol = "tcp"
    ip       = "::"
  }

  ports {
    internal = 4318
    external = 4318
    protocol = "tcp"
    ip       = "::"
  }

  volumes {
    container_path = "/etc/caddy/Caddyfile"
    host_path      = "${local.working_dir}/caddy/Caddyfile"
    read_only      = true
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.working_dir}/caddy/data"
  }

  volumes {
    container_path = "/config"
    host_path      = "${local.working_dir}/caddy/config"
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
  }

  depends_on = [
    docker_container.grafana,
    docker_container.otel,
    null_resource.caddy_config
  ]

  healthcheck {
    test         = ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/api/health"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
