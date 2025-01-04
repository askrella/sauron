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

# Promtail config
resource "null_resource" "promtail_config" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p ${local.promtail_config_path_dir}",
            "mkdir -p ${local.promtail_positions_dir}"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    provisioner "file" {
        content     = local.promtail_config_content
        destination = local.promtail_config_file_path

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    triggers = {
        content = local.promtail_config_content
        path    = local.promtail_config_file_path
    }

    depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all Promtail configs
resource "null_resource" "promtail_configs" {
    triggers = {
        config = null_resource.promtail_config.id
    }

    depends_on = [
        null_resource.promtail_config
    ]
}
