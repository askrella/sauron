locals {
    # Thanos Ruler config paths
    thanos_ruler_config_path_dir = "${local.working_dir}/thanos/ruler/config"
    thanos_ruler_config_file_path = "${local.thanos_ruler_config_path_dir}/ruler.yaml"
    thanos_ruler_data_dir = "${local.working_dir}/thanos/ruler/data"

    # Thanos Ruler config content
    thanos_ruler_config_content = templatefile("${path.module}/thanos/ruler.yaml", {
        bucket     = var.minio_bucket
        endpoint   = "${var.minio_region}.your-objectstorage.com"
        access_key = var.minio_user
        secret_key = var.minio_password
        region     = var.minio_region
        index      = var.index
    })
}

# Thanos Ruler config
resource "null_resource" "thanos_ruler_config" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p ${local.thanos_ruler_config_path_dir}",
            "mkdir -p ${local.thanos_ruler_data_dir}"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    provisioner "file" {
        content     = local.thanos_ruler_config_content
        destination = local.thanos_ruler_config_file_path

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    triggers = {
        content = local.thanos_ruler_config_content
        path    = local.thanos_ruler_config_file_path
    }

    depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all Thanos Ruler configs
resource "null_resource" "thanos_ruler_configs" {
    triggers = {
        config = null_resource.thanos_ruler_config.id
    }

    depends_on = [
        null_resource.thanos_ruler_config
    ]
}
