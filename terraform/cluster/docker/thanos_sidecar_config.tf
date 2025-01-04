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

# Thanos Sidecar config
resource "null_resource" "thanos_sidecar_config" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p ${local.thanos_sidecar_config_path_dir}"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    provisioner "file" {
        content     = local.thanos_sidecar_config_content
        destination = local.thanos_sidecar_config_file_path

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    triggers = {
        content = local.thanos_sidecar_config_content
        path    = local.thanos_sidecar_config_file_path
    }

    depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all Thanos Sidecar configs
resource "null_resource" "thanos_sidecar_configs" {
    triggers = {
        config = null_resource.thanos_sidecar_config.id
    }

    depends_on = [
        null_resource.thanos_sidecar_config
    ]
}
