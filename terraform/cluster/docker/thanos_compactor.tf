# Create Thanos Compactor configuration
resource "null_resource" "thanos_compactor_config" {

  provisioner "file" {
    content = templatefile("${path.module}/thanos/compactor.yaml", {
      bucket     = var.minio_bucket
      endpoint   = "${var.minio_region}.your-objectstorage.com"
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      index      = var.index
    })
    destination = "${local.working_dir}/thanos/compactor/config/compactor.yaml"
    
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

locals {
  thanos_compactor_label = "thanos-compact-${var.index}"
}

resource "docker_container" "thanos_compactor" {
  name  = "thanos-compact-${var.index}"
  image = docker_image.thanos.image_id

  restart = "unless-stopped"

  labels {
    label = "pod"
    value = local.thanos_compactor_label
  }

  command = [
    "compact",
    "--objstore.config-file=/etc/thanos/compactor.yaml",
    "--http-address=0.0.0.0:10902",
    "--data-dir=/data",
    "--retention.resolution-raw=7d",
    "--retention.resolution-5m=30d",
    "--retention.resolution-1h=90d",
    #"--downsampling.disable=false",
    "--delete-delay=48h"
  ]

  ports {
    internal = 10902
    external = 10912  # Using different port to avoid conflicts
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/thanos/compactor.yaml"
    host_path      = "${local.working_dir}/thanos/compactor/config/compactor.yaml"
    read_only      = true
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.working_dir}/thanos/compactor/data"
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

  user = "65534"  # nobody user

  log_opts = {
    max-size = "10m"
    max-file = "3"
  }

  security_opts = [
    "no-new-privileges:true"
  ]

  dns = [
    "fedc::1", # Docker DNS
    "2606:4700:4700::1111", # Cloudflare DNS
    "2606:4700:4700::1001" # Cloudflare DNS fallback
  ]

  depends_on = [
    docker_image.thanos,
    null_resource.setup_directories,
    null_resource.thanos_compactor_config
  ]
}
