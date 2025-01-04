# Create required directories
resource "null_resource" "promtail_config_dirs" {
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.working_dir}/promtail/config",
      "mkdir -p ${local.working_dir}/promtail/positions"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }
}

# Create the Promtail configuration file
resource "null_resource" "promtail_config" {
  provisioner "file" {
    content = templatefile("${path.module}/promtail/config.yaml", {
      bucket     = var.minio_bucket
      endpoint   = "${var.minio_region}.your-objectstorage.com"
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      index      = var.index
    })
    destination = "${local.working_dir}/promtail/config/config.yaml"

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

resource "docker_image" "promtail" {
  name         = "grafana/promtail:${var.promtail_version}"
  keep_locally = true


  depends_on = [
    null_resource.docker_network,
    null_resource.promtail_config
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
    host_path      = "${local.working_dir}/promtail/config/config.yaml"
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
    host_path      = "${local.working_dir}/promtail/positions"
  }

  command = [
    "--config.file=/etc/promtail/config.yaml"
  ]

  networks_advanced {
    name = docker_network.monitoring.name
  }

  depends_on = [
    null_resource.docker_network,
    null_resource.promtail_config
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
  }
}
