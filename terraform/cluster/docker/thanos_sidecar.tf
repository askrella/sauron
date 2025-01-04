resource "docker_image" "thanos" {
  name         = "quay.io/thanos/thanos:v0.37.2"
  keep_locally = true

  depends_on = [
    null_resource.docker_network
  ]
}

# Create Thanos sidecar configuration
resource "null_resource" "thanos_sidecar_config" {
  connection {
    type        = "ssh"
    user        = "root"
    host        = var.server_ipv6_address
    private_key = file(var.ssh_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/thanos/sidecar.yaml", {
      bucket     = var.minio_bucket
      endpoint   = local.minio_endpoint
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      index      = var.index
    })
    destination = "${local.working_dir}/thanos/sidecar/config/sidecar.yaml"
  }

  triggers = {
    timestamp = timestamp()
  }

  depends_on = [null_resource.setup_directories]
}

locals {
  thanos_sidecar_label = "thanos-sidecar-${var.index}"
}

resource "docker_container" "thanos_sidecar" {
  name  = "thanos-sidecar-${var.index}"
  image = docker_image.thanos.image_id

  labels {
    label = "pod"
    value = local.thanos_sidecar_label
  }

  command = [
    "sidecar",
    "--objstore.config-file=/etc/thanos/sidecar.yaml",
    "--tsdb.path=/prometheus/data",
    "--log.level=debug",
    "--prometheus.url=http://prometheus-${var.index}:9090",
    "--http-address=0.0.0.0:10902",
    "--grpc-address=0.0.0.0:10901"
  ]

  ports {
    internal = 10901
    external = 10901
    protocol = "tcp"
  }

  ports {
    internal = 10902
    external = 10902
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/thanos/sidecar.yaml"
    host_path      = "${local.working_dir}/thanos/sidecar/config/sidecar.yaml"
    read_only      = true
  }

  volumes {
    container_path = "/prometheus"
    host_path      = "${local.working_dir}/prometheus/data"
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

  user = "65534" # nobody user

  log_opts = {
    max-size = "10m"
    max-file = "3"
  }

  security_opts = [
    "no-new-privileges:true"
  ]

  depends_on = [
    docker_container.prometheus,
    null_resource.setup_directories,
    null_resource.thanos_sidecar_config
  ]

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]
  }
}
