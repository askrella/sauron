locals {
    # Loki config paths
    loki_config_path_dir = "${local.working_dir}/loki/config"
    loki_config_file_path = "${local.loki_config_path_dir}/config.yaml"
    loki_data_dir = "${local.working_dir}/loki/data"

    # Loki config content
    loki_config_content = templatefile("${path.module}/loki/config.yaml", {
        loki_members         = join("\n", [for node_ip in local.other_server_ips : "    - ${node_ip}:7946"])
        bucket_access_key    = var.minio_user
        bucket_access_secret = var.minio_password
        bucket_endpoint      = local.minio_endpoint
        bucket_name         = var.minio_bucket
        bucket_region       = var.minio_region
        replication_factor  = local.node_count >= 3 ? 3 : 1
    })
}

# Create config directory
resource "ssh_directory" "loki_config_dir" {
  path        = local.loki_config_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Create data directory
resource "ssh_directory" "loki_data_dir" {
  path        = local.loki_data_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Loki config
resource "ssh_file" "loki_config" {
  content     = local.loki_config_content
  path = local.loki_config_file_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [
    ssh_directory.loki_config_dir,
    ssh_directory.loki_data_dir
  ]
}

# Aggregate resource to depend on all Loki configs
resource "null_resource" "loki_configs" {
  triggers = {
    config = ssh_file.loki_config.id
  }

  depends_on = [
    ssh_file.loki_config
  ]
}
