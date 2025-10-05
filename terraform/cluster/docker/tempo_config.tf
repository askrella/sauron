locals {
    # Tempo config paths
    tempo_config_path_dir = "${local.working_dir}/tempo/config"
    tempo_config_file_path = "${local.tempo_config_path_dir}/config.yaml"
    tempo_data_dir = "${local.working_dir}/tempo/data"
    tempo_wal_dir = "${local.tempo_data_dir}/wal"

    # Tempo config content
    tempo_config_content = templatefile("${path.module}/tempo/config.yaml", {
        ip            = var.server_ipv6_address
        bucket        = var.minio_bucket
        endpoint      = local.minio_endpoint
        access_key    = var.minio_user
        secret_key    = var.minio_password
        region        = var.minio_region
        node_id       = var.index
        tempo_members = join("\n", [for node_ip in local.other_server_ips : "    - ${node_ip}:7956"])
    })
}

# Create config directory
resource "ssh_directory" "tempo_config_dir" {
  path        = local.tempo_config_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Create data directory
resource "ssh_directory" "tempo_data_dir" {
  path        = local.tempo_data_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Create WAL directory
resource "ssh_directory" "tempo_wal_dir" {
  path        = local.tempo_wal_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.tempo_data_dir]
}

resource "null_resource" "set_ownership_tempo" {
  provisioner "remote-exec" {
    inline = [
      "chown -R 65534:65534 ${local.working_dir}/tempo"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  depends_on = [
    ssh_directory.tempo_config_dir,
    ssh_directory.tempo_data_dir,
    ssh_directory.tempo_wal_dir
  ]
}

# Tempo config
resource "ssh_file" "tempo_config" {
  content     = local.tempo_config_content
  path = local.tempo_config_file_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [
    ssh_directory.tempo_config_dir,
    null_resource.set_ownership_tempo
  ]
}

# Aggregate resource to depend on all Tempo configs
resource "null_resource" "tempo_configs" {
  triggers = {
    config = ssh_file.tempo_config.id
  }

  depends_on = [
    ssh_file.tempo_config
  ]
}
