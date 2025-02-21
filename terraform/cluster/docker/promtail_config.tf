locals {
    # Promtail config paths
    promtail_config_path_dir = "${local.working_dir}/promtail/config"
    promtail_config_file_path = "${local.promtail_config_path_dir}/config.yaml"
    promtail_positions_dir = "${local.working_dir}/promtail/positions"

    # Promtail config content
    promtail_config_content = templatefile("${path.module}/promtail/config.yaml", {
        bucket     = var.minio_bucket
        endpoint   = "${var.minio_region}.your-objectstorage.com"
        access_key = var.minio_user
        secret_key = var.minio_password
        region     = var.minio_region
        index      = var.index
    })
}

# Create config directory
resource "ssh_directory" "promtail_config_dir" {
  path        = local.promtail_config_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Create positions directory
resource "ssh_directory" "promtail_positions_dir" {
  path        = local.promtail_positions_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Promtail config
resource "ssh_file" "promtail_config" {
  content     = local.promtail_config_content
  path = local.promtail_config_file_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [
    ssh_directory.promtail_config_dir,
    ssh_directory.promtail_positions_dir
  ]
}

# Aggregate resource to depend on all Promtail configs
resource "null_resource" "promtail_configs" {
  triggers = {
    config = ssh_file.promtail_config.id
  }

  depends_on = [
    ssh_file.promtail_config
  ]
}
