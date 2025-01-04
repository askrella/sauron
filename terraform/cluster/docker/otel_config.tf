locals {
    # OpenTelemetry config paths
    otel_config_path_dir = "${local.working_dir}/otel/config"
    otel_config_file_path = "${local.otel_config_path_dir}/config.yml"

    # OpenTelemetry config content
    otel_config_content = templatefile("${path.module}/otel/config.yml", {
        index = var.index
    })
}

# OpenTelemetry config
resource "null_resource" "otel_config" {
    provisioner "remote-exec" {
        inline = [
            "mkdir -p ${local.otel_config_path_dir}"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    provisioner "file" {
        content     = local.otel_config_content
        destination = local.otel_config_file_path

        connection {
            type        = "ssh"
            user        = "root"
            host        = var.server_ipv6_address
            private_key = file(var.ssh_key_path)
        }
    }

    triggers = {
        content = local.otel_config_content
        path    = local.otel_config_file_path
    }

    depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all OpenTelemetry configs
resource "null_resource" "otel_configs" {
    triggers = {
        config = null_resource.otel_config.id
    }

    depends_on = [
        null_resource.otel_config
    ]
}
