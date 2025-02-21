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

# Create directories
resource "ssh_directory" "grafana_dashboards_dir" {
  path        = local.grafana_dashboards_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username =        "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

resource "ssh_directory" "grafana_datasources_dir" {
  path        = local.grafana_datasources_path_dir
  permissions = "0755"

  ssh = {
    host        = var.server_ipv6_address
    username =        "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Dashboards provider config
resource "ssh_file" "grafana_dashboards_provider" {
  content     = local.grafana_dashboards_content
  path = local.grafana_dashboards_config_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.grafana_dashboards_dir]
}

# cAdvisor dashboard
resource "ssh_file" "grafana_dashboard_cadvisor" {
  content     = local.grafana_dashboard_cadvisor_content
  path = local.grafana_dashboard_cadvisor_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.grafana_dashboards_dir]
}

# Node exporter dashboard
resource "ssh_file" "grafana_dashboard_node_exporter" {
  content     = local.grafana_dashboard_node_exporter_content
  path = local.grafana_dashboard_node_exporter_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.grafana_dashboards_dir]
}

# Thanos dashboard
resource "ssh_file" "grafana_dashboard_thanos" {
  content     = local.grafana_dashboard_thanos_content
  path = local.grafana_dashboard_thanos_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.grafana_dashboards_dir]
}

# Loki dashboard
resource "ssh_file" "grafana_dashboard_askrella_loki" {
  content     = local.grafana_dashboard_askrella_loki_content
  path = local.grafana_dashboard_askrella_loki_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.grafana_dashboards_dir]
}

# Grafana.ini config
resource "ssh_file" "grafana_ini" {
  content     = local.grafana_ini_content
  path = local.grafana_ini_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [null_resource.setup_directories]
}

# Datasources config
resource "ssh_file" "grafana_datasources" {
  content     = local.grafana_datasources_content
  path = local.grafana_datasources_config_path
  permissions = "0644"

  ssh = {
    host        = var.server_ipv6_address
    username = "root"
    private_key = file(var.ssh_key_path)
  }

  depends_on = [ssh_directory.grafana_datasources_dir]
}

# Aggregate resource to depend on all Grafana configs
resource "null_resource" "grafana_configs" {
  triggers = {
    dashboards_provider = ssh_file.grafana_dashboards_provider.id
    dashboard_cadvisor = ssh_file.grafana_dashboard_cadvisor.id
    dashboard_node_exporter = ssh_file.grafana_dashboard_node_exporter.id
    dashboard_thanos = ssh_file.grafana_dashboard_thanos.id
    dashboard_loki = ssh_file.grafana_dashboard_askrella_loki.id
    grafana_ini = ssh_file.grafana_ini.id
    datasources = ssh_file.grafana_datasources.id
  }

  depends_on = [
    ssh_file.grafana_dashboards_provider,
    ssh_file.grafana_dashboard_cadvisor,
    ssh_file.grafana_dashboard_node_exporter,
    ssh_file.grafana_dashboard_thanos,
    ssh_file.grafana_dashboard_askrella_loki,
    ssh_file.grafana_ini,
    ssh_file.grafana_datasources
  ]
}
