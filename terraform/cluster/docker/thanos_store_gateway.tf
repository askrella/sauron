# Create Thanos Store Gateway configuration
resource "null_resource" "thanos_store_gateway_config" {


  provisioner "file" {
    content = templatefile("${path.module}/thanos/store.yaml", {
      bucket     = var.minio_bucket
      endpoint   = "${var.minio_region}.your-objectstorage.com"
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      index      = var.index
    })
    destination = "${local.working_dir}/thanos/store/config/store.yaml"

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
  thanos_store_gateway_label = "thanos-store-${var.index}"
}

resource "docker_container" "thanos_store" {
  name  = "thanos-store-${var.index}"
  image = docker_image.thanos.image_id

  restart = "unless-stopped"

  labels {
    label = "pod"
    value = local.thanos_store_gateway_label
  }

  command = [
    "store",
    "--objstore.config-file=/etc/thanos/store.yaml",
    "--http-address=0.0.0.0:10906",
    "--grpc-address=0.0.0.0:10905",
    "--data-dir=/data"
  ]

  ports {
    internal = 10905
    external = 10905
    protocol = "tcp"
  }

  ports {
    internal = 10906
    external = 10906
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/thanos/store.yaml"
    host_path      = "${local.working_dir}/thanos/store/config/store.yaml"
    read_only      = true
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.working_dir}/thanos/store/data"
    read_only      = false
  }

  healthcheck {
    test         = ["CMD", "wget", "--spider", "http://localhost:10906/-/healthy"]
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
    docker_image.thanos,
    null_resource.setup_directories,
    null_resource.thanos_store_gateway_config
  ]
}
