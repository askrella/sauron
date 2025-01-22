locals {
  # MariaDB config paths
  mariadb_config_path_dir = "${local.working_dir}/mariadb/config"
  mariadb_config_file_path = "${local.mariadb_config_path_dir}/galera.cnf"
  mariadb_data_dir = "${local.working_dir}/mariadb/data"

  # MariaDB config content
  mariadb_config_content = templatefile("${path.module}/mariadb/galera.cnf", {
    server_id           = var.index
    cluster_name        = "galera_cluster"
    cluster_address     = join(",", [for ip in var.cluster_ipv6_addresses : "gcomm://[${ip}]:4567"])
    node_address        = var.server_ipv6_address
    node_name          = "node${var.index}"
    backup_bucket      = var.minio_bucket
    backup_region      = var.minio_region
    backup_access_key  = var.minio_user
    backup_secret_key  = var.minio_password
    backup_endpoint    = local.minio_endpoint
    backup_path        = "galera"
  })
}

# MariaDB config
resource "null_resource" "mariadb_config" {
  provisioner "file" {
    content     = local.mariadb_config_content
    destination = local.mariadb_config_file_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.mariadb_config_content
    path    = local.mariadb_config_file_path
  }

  depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all MariaDB configs
resource "null_resource" "mariadb_configs" {
  triggers = {
    config = null_resource.mariadb_config.id
  }

  depends_on = [
    null_resource.mariadb_config
  ]
}
