variable "tempo_version" {
  type    = string
  default = "2.6.1"
  description = "The version of Tempo to use"
}

variable "tempo_port" {
  type    = number
  default = 3200
  description = "The port to expose Tempo on"
}

# Create required directories
resource "null_resource" "tempo_config_dirs" {
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.working_dir}/tempo/config",
      "mkdir -p ${local.working_dir}/tempo/data",
      "mkdir -p ${local.working_dir}/tempo/data/wal",
      "chown -R 65534:65534 ${local.working_dir}/tempo"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  depends_on = [null_resource.setup_directories]
}

# Create the Tempo configuration file
resource "null_resource" "tempo_config" {
  provisioner "file" {
    content = templatefile("${path.module}/tempo/config.yaml", {
      bucket     = var.minio_bucket
      endpoint   = local.minio_endpoint
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      tempo_members = join("\n", [for node_ip in local.other_server_ips : "    - ${node_ip}:7946"])
    })
    destination = "${local.working_dir}/tempo/config/config.yaml"

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

  depends_on = [null_resource.tempo_config_dirs]
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
    internal = 4317
    external = 4317
    protocol = "tcp"
  }

  ports {
    internal = 4318
    external = 4318
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/tempo/config.yaml"
    host_path      = "${local.working_dir}/tempo/config/config.yaml"
    read_only      = true
  }

  volumes {
    container_path = "/tmp/tempo"
    host_path      = "${local.working_dir}/tempo/data"
    read_only      = false
  }

  volumes {
    container_path = "/tmp/tempo/wal"
    host_path      = "${local.working_dir}/tempo/data/wal"
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
    null_resource.tempo_config
  ]
} 