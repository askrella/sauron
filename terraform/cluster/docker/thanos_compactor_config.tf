locals {
    # Thanos Compactor config paths
    thanos_compactor_config_path_dir = "${local.working_dir}/thanos/compactor/config"
    thanos_compactor_config_file_path = "${local.thanos_compactor_config_path_dir}/compactor.yaml"
    thanos_compactor_data_dir = "${local.working_dir}/thanos/compactor/data"

    # Thanos Compactor config content
    thanos_compactor_config_content = templatefile("${path.module}/thanos/compactor.yaml", {
        bucket     = var.minio_bucket
        endpoint   = "${var.minio_region}.your-objectstorage.com"
        access_key = var.minio_user
        secret_key = var.minio_password
        region     = var.minio_region
        index      = var.index
    })
}

# Create config directory
resource "ssh_directory" "thanos_compactor_config_dir" {
  path        = local.thanos_compactor_config_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Create data directory
resource "ssh_directory" "thanos_compactor_data_dir" {
  path        = local.thanos_compactor_data_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Thanos Compactor config
resource "ssh_file" "thanos_compactor_config" {
  content     = local.thanos_compactor_config_content
  path = local.thanos_compactor_config_file_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [
    ssh_directory.thanos_compactor_config_dir,
    ssh_directory.thanos_compactor_data_dir
  ]
}

# Aggregate resource to depend on all Thanos Compactor configs
resource "null_resource" "thanos_compactor_configs" {
  triggers = {
    config = ssh_file.thanos_compactor_config.id
  }

  depends_on = [
    ssh_file.thanos_compactor_config
  ]
}
