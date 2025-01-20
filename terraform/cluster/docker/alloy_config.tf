locals {
  alloy_config_content = templatefile("${path.module}/alloy/config.alloy", {
        index = var.index
  })
  alloy_config_path = "${local.working_dir}/alloy/config/config.alloy"
}

resource "null_resource" "alloy_config" {
  provisioner "file" {
    content     = local.alloy_config_content
    destination = local.alloy_config_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.alloy_config_content
    path    = local.alloy_config_path
  }

  depends_on = [null_resource.setup_directories]
}

resource "null_resource" "alloy_configs" {
  triggers = {
    config = null_resource.alloy_config.id
  }

  depends_on = [null_resource.alloy_config]
}
