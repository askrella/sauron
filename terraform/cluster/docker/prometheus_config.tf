locals {
    # Prometheus config paths
    prometheus_config_path_dir = "${local.working_dir}/prometheus/config"
    prometheus_config_file_path = "${local.prometheus_config_path_dir}/prometheus.yml"
    prometheus_data_dir = "${local.working_dir}/prometheus/data"

    # Prometheus config content
    prometheus_config_content = templatefile("${path.module}/prometheus/config.yml", {
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
}

# Create config directory
resource "ssh_directory" "prometheus_config_dir" {
  path        = local.prometheus_config_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Create data directory
resource "ssh_directory" "prometheus_data_dir" {
  path        = local.prometheus_data_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Prometheus config
resource "ssh_file" "prometheus_config" {
  content     = local.prometheus_config_content
  path = local.prometheus_config_file_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [
    ssh_directory.prometheus_config_dir,
    ssh_directory.prometheus_data_dir
  ]
}

# Aggregate resource to depend on all Prometheus configs
resource "null_resource" "prometheus_configs" {
  triggers = {
    config = ssh_file.prometheus_config.id
  }

  depends_on = [
    ssh_file.prometheus_config
  ]
}
