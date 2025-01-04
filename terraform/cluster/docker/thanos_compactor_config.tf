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

# Thanos Compactor config
resource "null_resource" "thanos_compactor_config" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p ${local.thanos_compactor_config_path_dir}",
            "mkdir -p ${local.thanos_compactor_data_dir}"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    provisioner "file" {
        content     = local.thanos_compactor_config_content
        destination = local.thanos_compactor_config_file_path

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    triggers = {
        content = local.thanos_compactor_config_content
        path    = local.thanos_compactor_config_file_path
    }

    depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all Thanos Compactor configs
resource "null_resource" "thanos_compactor_configs" {
    triggers = {
        config = null_resource.thanos_compactor_config.id
    }

    depends_on = [
        null_resource.thanos_compactor_config
    ]
}
