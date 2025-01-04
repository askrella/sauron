locals {
    # Prometheus config paths
    prometheus_config_path_dir = "${local.working_dir}/prometheus/config"
    prometheus_config_file_path = "${local.prometheus_config_path_dir}/prometheus.yml"
    prometheus_data_dir = "${local.working_dir}/prometheus/data"

    # Prometheus config content
    prometheus_config_content = templatefile("${path.module}/prometheus/config.yml", {
        bucket     = var.minio_bucket
        endpoint   = "${var.minio_region}.your-objectstorage.com"
        access_key = var.minio_user
        secret_key = var.minio_password
        region     = var.minio_region
        index      = var.index
        cluster    = "sauron"
        node       = var.index
        node_ip    = var.server_ipv6_address
    })
}

# Prometheus config
resource "null_resource" "prometheus_config" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p ${local.prometheus_config_path_dir}",
            "mkdir -p ${local.prometheus_data_dir}"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    provisioner "file" {
        content     = local.prometheus_config_content
        destination = local.prometheus_config_file_path

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    triggers = {
        content = local.prometheus_config_content
        path    = local.prometheus_config_file_path
    }

    depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all Prometheus configs
resource "null_resource" "prometheus_configs" {
    triggers = {
        config = null_resource.prometheus_config.id
    }

    depends_on = [
        null_resource.prometheus_config
    ]
}
