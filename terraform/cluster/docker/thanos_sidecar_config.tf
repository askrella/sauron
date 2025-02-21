locals {
    # Thanos Sidecar config paths
    thanos_sidecar_config_path_dir = "${local.working_dir}/thanos/sidecar/config"
    thanos_sidecar_config_file_path = "${local.thanos_sidecar_config_path_dir}/sidecar.yaml"
    thanos_sidecar_data_dir = "${local.working_dir}/prometheus/data"  # Uses Prometheus data dir

    # Thanos Sidecar config content
    thanos_sidecar_config_content = templatefile("${path.module}/thanos/sidecar.yaml", {
        bucket     = var.minio_bucket
        endpoint   = local.minio_endpoint
        access_key = var.minio_user
        secret_key = var.minio_password
        region     = var.minio_region
        index      = var.index
    })
}

# Create config directory
resource "ssh_directory" "thanos_sidecar_config_dir" {
  path        = local.thanos_sidecar_config_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username       = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Thanos Sidecar config
resource "ssh_file" "thanos_sidecar_config" {
  content     = local.thanos_sidecar_config_content
  path = local.thanos_sidecar_config_file_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username       = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.thanos_sidecar_config_dir]
}

# Aggregate resource to depend on all Thanos Sidecar configs
resource "null_resource" "thanos_sidecar_configs" {
  triggers = {
    config = ssh_file.thanos_sidecar_config.id
  }

  depends_on = [
    ssh_file.thanos_sidecar_config
  ]
}
