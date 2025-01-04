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

# Thanos Store Gateway config
resource "null_resource" "thanos_store_gateway_config" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p ${local.thanos_store_gateway_config_path_dir}",
            "mkdir -p ${local.thanos_store_gateway_data_dir}"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    provisioner "file" {
        content     = local.thanos_store_gateway_config_content
        destination = local.thanos_store_gateway_config_file_path

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    triggers = {
        content = local.thanos_store_gateway_config_content
        path    = local.thanos_store_gateway_config_file_path
    }

    depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all Thanos Store Gateway configs
resource "null_resource" "thanos_store_gateway_configs" {
    triggers = {
        config = null_resource.thanos_store_gateway_config.id
    }

    depends_on = [
        null_resource.thanos_store_gateway_config
    ]
}
