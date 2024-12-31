# Create required directories
resource "null_resource" "loki_config_dirs" {
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.working_dir}/loki/config",
      "mkdir -p ${local.working_dir}/loki/data"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }
}

locals {
  node_count = length(var.cluster_ipv4_addresses)
}

# Create the Loki configuration file
resource "null_resource" "loki_config" {
  provisioner "file" {
    content     = templatefile("${path.module}/loki/config.yaml", {
      loki_members = join("\n", [for node_ip in local.other_server_ips : "    - ${node_ip}:7946"])
      bucket_access_key = var.minio_user
      bucket_access_secret = var.minio_password
      bucket_endpoint = local.minio_endpoint
      bucket_name = var.minio_bucket
      bucket_region = var.minio_region

      replication_factor = local.node_count >= 3 ? 3 : 1
    })
    destination = "${local.working_dir}/loki/config/config.yaml"

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

resource "docker_image" "loki" {
  name = "grafana/loki:${var.loki_version}"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "loki" {
  name  = "loki-${var.index}"
  image = docker_image.loki.image_id

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
    host_path      = "${local.working_dir}/loki/config/config.yaml"
    read_only      = true
  }

  volumes {
    container_path = "/loki"
    host_path      = "${local.working_dir}/loki/data"
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
    null_resource.loki_config
  ]

  dns = [
    "fedc::1", # Docker DNS
    "2606:4700:4700::1111", # Cloudflare DNS
    "2606:4700:4700::1001" # Cloudflare DNS fallback
  ]

  user = "10001"

  healthcheck {
    test = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
    start_period = "30s"
  }
}
