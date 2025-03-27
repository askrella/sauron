locals {
    # Thanos Store Gateway config paths
    thanos_store_gateway_config_path_dir = "${local.working_dir}/thanos/store/config"
    thanos_store_gateway_config_file_path = "${local.thanos_store_gateway_config_path_dir}/store.yaml"
    thanos_store_gateway_data_dir = "${local.working_dir}/thanos/store/data"

    # Thanos Store Gateway config content
    thanos_store_gateway_config_content = templatefile("${path.module}/thanos/store.yaml", {
        bucket     = var.minio_bucket
        endpoint   = "${var.minio_region}.your-objectstorage.com"
        access_key = var.minio_user
        secret_key = var.minio_password
        region     = var.minio_region
        index      = var.index
    })
}

# Create config directory
resource "ssh_directory" "thanos_store_gateway_config_dir" {
  path        = local.thanos_store_gateway_config_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username       = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Create data directory
resource "ssh_directory" "thanos_store_gateway_data_dir" {
  path        = local.thanos_store_gateway_data_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username       = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Thanos Store Gateway config
resource "ssh_file" "thanos_store_gateway_config" {
  content     = local.thanos_store_gateway_config_content
  path = local.thanos_store_gateway_config_file_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username       = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [
    ssh_directory.thanos_store_gateway_config_dir,
    ssh_directory.thanos_store_gateway_data_dir
  ]
}

# Aggregate resource to depend on all Thanos Store Gateway configs
resource "null_resource" "thanos_store_gateway_configs" {
  triggers = {
    config = ssh_file.thanos_store_gateway_config.id
  }

  depends_on = [
    ssh_file.thanos_store_gateway_config
  ]
}
