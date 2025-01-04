locals {
    # Tempo config paths
    tempo_config_path_dir = "${local.working_dir}/tempo/config"
    tempo_config_file_path = "${local.tempo_config_path_dir}/config.yaml"
    tempo_data_dir = "${local.working_dir}/tempo/data"
    tempo_wal_dir = "${local.tempo_data_dir}/wal"

    # Tempo config content
    tempo_config_content = templatefile("${path.module}/tempo/config.yaml", {
        bucket        = var.minio_bucket
        endpoint      = local.minio_endpoint
        access_key    = var.minio_user
        secret_key    = var.minio_password
        region        = var.minio_region
        tempo_members = join("\n", [for node_ip in local.other_server_ips : "    - ${node_ip}:7956"])
    })
}

# Tempo config
resource "null_resource" "tempo_config" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p ${local.tempo_config_path_dir}",
            "mkdir -p ${local.tempo_data_dir}",
            "mkdir -p ${local.tempo_wal_dir}",
            "chown -R 65534:65534 ${local.working_dir}/tempo"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    provisioner "file" {
        content     = local.tempo_config_content
        destination = local.tempo_config_file_path

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    triggers = {
        content = local.tempo_config_content
        path    = local.tempo_config_file_path
    }

    depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all Tempo configs
resource "null_resource" "tempo_configs" {
    triggers = {
        config = null_resource.tempo_config.id
    }

    depends_on = [
        null_resource.tempo_config
    ]
}
