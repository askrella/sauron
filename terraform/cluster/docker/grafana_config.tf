locals {
    # Dashboards provider config
    grafana_dashboards_content = <<-EOT
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
    EOT
    grafana_dashboards_path_dir = "${local.working_dir}/grafana/config/dashboards"
    grafana_dashboards_config_path = "${local.grafana_dashboards_path_dir}/dashboards.yaml"

    # Dashboard paths
    grafana_dashboard_cadvisor_path = "${local.working_dir}/grafana/config/dashboards/cAdvisor.json"
    grafana_dashboard_node_exporter_path = "${local.working_dir}/grafana/config/dashboards/node-exporter.json"
    grafana_dashboard_thanos_path = "${local.working_dir}/grafana/config/dashboards/thanos.json"
    grafana_dashboard_askrella_loki_path = "${local.working_dir}/grafana/config/dashboards/askrella-loki.json"

    # Dashboard contents
    grafana_dashboard_cadvisor_content = file("${path.module}/grafana/config/dashboards/cAdvisor.json")
    grafana_dashboard_node_exporter_content = file("${path.module}/grafana/config/dashboards/node-exporter.json")
    grafana_dashboard_thanos_content = file("${path.module}/grafana/config/dashboards/thanos.json")
    grafana_dashboard_askrella_loki_content = templatefile("${path.module}/grafana/config/dashboards/askrella-loki.json", {
      required_loki_nodes = local.node_count >= 3 ? 3 : local.node_count
    })

    # Grafana.ini config
    grafana_ini_path = "${local.working_dir}/grafana/config/grafana.ini"
    grafana_ini_content = templatefile("${path.module}/grafana/config/grafana.ini", {
      domain = var.domain
      index  = var.index
    })

    # Datasources config
    grafana_datasources_path_dir = "${local.working_dir}/grafana/config/provisioning/datasources"
    grafana_datasources_config_path = "${local.grafana_datasources_path_dir}/datasources.yaml"
    grafana_datasources_content = templatefile("${path.module}/grafana/config/provisioning/datasources/datasources.yaml", {
      bucket     = var.minio_bucket
      endpoint   = "${var.minio_region}.your-objectstorage.com"
      access_key = var.minio_user
      secret_key = var.minio_password
      region     = var.minio_region
      index      = var.index
    })
}

# Dashboards provider config
resource "null_resource" "grafana_dashboards_provider" {
  provisioner "file" {
    content     = local.grafana_dashboards_content
    destination = local.grafana_dashboards_config_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.grafana_dashboards_content
    path    = local.grafana_dashboards_config_path
  }

  depends_on = [null_resource.setup_directories]
}

# cAdvisor dashboard
resource "null_resource" "grafana_dashboard_cadvisor" {
  provisioner "file" {
    content     = local.grafana_dashboard_cadvisor_content
    destination = local.grafana_dashboard_cadvisor_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.grafana_dashboard_cadvisor_content
    path    = local.grafana_dashboard_cadvisor_path
  }

  depends_on = [null_resource.setup_directories]
}

# Node exporter dashboard
resource "null_resource" "grafana_dashboard_node_exporter" {
  provisioner "file" {
    content     = local.grafana_dashboard_node_exporter_content
    destination = local.grafana_dashboard_node_exporter_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.grafana_dashboard_node_exporter_content
    path    = local.grafana_dashboard_node_exporter_path
  }

  depends_on = [null_resource.setup_directories]
}

# Thanos dashboard
resource "null_resource" "grafana_dashboard_thanos" {
  provisioner "file" {
    content     = local.grafana_dashboard_thanos_content
    destination = local.grafana_dashboard_thanos_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.grafana_dashboard_thanos_content
    path    = local.grafana_dashboard_thanos_path
  }

  depends_on = [null_resource.setup_directories]
}

# Loki dashboard
resource "null_resource" "grafana_dashboard_askrella_loki" {
  provisioner "file" {
    content     = local.grafana_dashboard_askrella_loki_content
    destination = local.grafana_dashboard_askrella_loki_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.grafana_dashboard_askrella_loki_content
    path    = local.grafana_dashboard_askrella_loki_path
  }

  depends_on = [null_resource.setup_directories]
}

# Grafana.ini config
resource "null_resource" "grafana_ini" {
  provisioner "remote-exec" {
    inline = [
      "rm -rf ${local.grafana_ini_path}",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  provisioner "file" {
    content     = local.grafana_ini_content
    destination = local.grafana_ini_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.grafana_ini_content
    path    = local.grafana_ini_path
  }

  depends_on = [null_resource.setup_directories]
}

# Datasources config
resource "null_resource" "grafana_datasources" {
  provisioner "file" {
    content     = local.grafana_datasources_content
    destination = local.grafana_datasources_config_path

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.server_ipv6_address
      private_key = file(var.ssh_key_path)
    }
  }

  triggers = {
    content = local.grafana_datasources_content
    path    = local.grafana_datasources_config_path
  }

  depends_on = [null_resource.setup_directories]
}

# Aggregate resource to depend on all Grafana configs
resource "null_resource" "grafana_configs" {
  triggers = {
    dashboards_provider = null_resource.grafana_dashboards_provider.id
    dashboard_cadvisor = null_resource.grafana_dashboard_cadvisor.id
    dashboard_node_exporter = null_resource.grafana_dashboard_node_exporter.id
    dashboard_thanos = null_resource.grafana_dashboard_thanos.id
    dashboard_loki = null_resource.grafana_dashboard_askrella_loki.id
    grafana_ini = null_resource.grafana_ini.id
    datasources = null_resource.grafana_datasources.id
  }

  depends_on = [
    null_resource.grafana_dashboards_provider,
    null_resource.grafana_dashboard_cadvisor,
    null_resource.grafana_dashboard_node_exporter,
    null_resource.grafana_dashboard_thanos,
    null_resource.grafana_dashboard_askrella_loki,
    null_resource.grafana_ini,
    null_resource.grafana_datasources
  ]
}
