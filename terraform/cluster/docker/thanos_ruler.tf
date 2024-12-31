# Create Thanos Ruler configuration
resource "null_resource" "thanos_ruler_config" {

  provisioner "file" {
    content = templatefile("${path.module}/thanos/ruler.yaml", {
      bucket     = var.minio_bucket
      endpoint   = "${var.minio_region}.your-objectstorage.com"
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      index      = var.index
    })
    destination = "${local.working_dir}/thanos/ruler/config/ruler.yaml"

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
  thanos_ruler_label = "thanos-ruler-${var.index}"
}

resource "docker_container" "thanos_ruler" {
  name  = "thanos-ruler-${var.index}"
  image = docker_image.thanos.image_id

  restart = "unless-stopped"

  labels {
    label = "pod"
    value = local.thanos_ruler_label
  }

  command = [
    "rule",
    "--objstore.config-file=/etc/thanos/ruler.yaml",
    "--rule-file=/etc/thanos/ruler/*.yaml",
    "--eval-interval=30s",
    "--http-address=0.0.0.0:10908",
    "--grpc-address=0.0.0.0:10907",
    "--data-dir=/data",
    "--query=thanos-querier-${var.index}:10903",
    "--alert.query-url=http://thanos-querier-${var.index}:10904",
    "--resend-delay=2m"
  ]

  ports {
    internal = 10907
    external = 10907
    protocol = "tcp"
  }

  ports {
    internal = 10908
    external = 10908
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/thanos/ruler.yaml"
    host_path      = "${local.working_dir}/thanos/ruler/config/ruler.yaml"
    read_only      = true
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.working_dir}/thanos/ruler/data"
    read_only      = false
  }

  healthcheck {
    test         = ["CMD", "wget", "--spider", "http://localhost:10908/-/healthy"]
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
    docker_container.thanos_querier,
    null_resource.thanos_ruler_config
  ]
}
