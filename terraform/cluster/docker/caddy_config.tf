locals {
    caddyfile_content = templatefile("${path.module}/caddy/Caddyfile", {
      domain  = var.domain
      node_id = var.index
      otel_collector_username = var.otel_collector_username
      otel_collector_password = replace(var.otel_collector_password, "$$", "$")
    })
    caddyfile_path = "${local.working_dir}/caddy/Caddyfile"
}

# Create config directory
resource "ssh_directory" "caddy_config_dir" {
  path        = dirname(local.caddyfile_path)
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username =       "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Caddy config
resource "ssh_file" "caddy_config" {
  content     = local.caddyfile_content
  path = local.caddyfile_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username =        "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.caddy_config_dir]
}

# Aggregate resource to depend on all Caddy configs
resource "null_resource" "caddy_configs" {
  triggers = {
    config = ssh_file.caddy_config.id
  }

  depends_on = [ssh_file.caddy_config]
}
