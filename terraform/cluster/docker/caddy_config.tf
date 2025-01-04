locals {
    caddyfile_content = templatefile("${path.module}/caddy/Caddyfile", {
      domain  = var.domain
      node_id = var.index
      otel_collector_username = var.otel_collector_username
      otel_collector_password = replace(var.otel_collector_password, "$$", "$")
    })
    caddyfile_path = "${local.working_dir}/caddy/Caddyfile"

}

resource "null_resource" "caddy_config" {
  provisioner "file" {
    content = local.caddyfile_content
    destination = local.caddyfile_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.caddyfile_content
    path = local.caddyfile_path
  }

  depends_on = [null_resource.setup_directories]
}
