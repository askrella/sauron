# Create the Prometheus configuration file
resource "null_resource" "prometheus_config" {
  provisioner "file" {
    content = templatefile("${path.module}/prometheus/config.yml", {
      bucket     = var.minio_bucket
      endpoint   = "${var.minio_region}.your-objectstorage.com"
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      index      = var.index
      cluster    = "sauron"
      node       = var.index
      node_ip    = var.server_ipv6_address
    })
    destination = "${local.working_dir}/prometheus/config/prometheus.yml"

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

resource "docker_image" "prometheus" {
  name = "prom/prometheus:${var.prometheus_version}"
  keep_locally = true

  depends_on = [
    null_resource.docker_network
  ]
}

resource "docker_container" "prometheus" {
  name  = "prometheus-${var.index}"
  image = docker_image.prometheus.image_id

  ports {
    internal = 9090
    external = var.prometheus_port
    protocol = "tcp"
  }

  volumes {
    container_path = "/etc/prometheus"
    host_path      = "${local.working_dir}/prometheus/config"
    read_only      = false
  }

  volumes {
    container_path = "/prometheus"
    host_path      = "${local.working_dir}/prometheus/data"
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--enable-feature=expand-external-labels",
    "--storage.tsdb.wal-compression",
    "--web.enable-lifecycle", # Allows Prometheus to reload its configuration
    "--web.enable-admin-api",
    "--storage.tsdb.min-block-duration=2h",
    "--storage.tsdb.max-block-duration=2h",
    "--storage.tsdb.retention.time=48h"
  ]

  healthcheck {
    test = ["CMD", "wget", "--spider", "http://localhost:9090/-/healthy"]
    interval = "30s"
    timeout = "10s"
    retries = 3
    start_period = "30s"
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  user = "65534"  # nobody user

  log_opts = {
    max-size = "10m"
    max-file = "3"
  }

  security_opts = [
    "no-new-privileges:true"
  ]

  depends_on = [
    null_resource.data_collectors_up,
    null_resource.prometheus_config,
    null_resource.setup_directories
  ]
}
