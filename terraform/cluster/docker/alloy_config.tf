locals {
  alloy_config_content = templatefile("${path.module}/alloy/config.alloy", {
        index = var.index
  })
  alloy_config_path = "${local.working_dir}/alloy/config/config.alloy"
}

# Create config directory
resource "ssh_directory" "alloy_config_dir" {
  path        = dirname(local.alloy_config_path)
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username =        "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Alloy config
resource "ssh_file" "alloy_config" {
  content     = local.alloy_config_content
  path = local.alloy_config_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username =        "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.alloy_config_dir]
}

# Aggregate resource to depend on all Alloy configs
resource "null_resource" "alloy_configs" {
  triggers = {
    config = ssh_file.alloy_config.id
  }

  depends_on = [ssh_file.alloy_config]
}
