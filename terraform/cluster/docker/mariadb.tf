resource "docker_image" "mariadb" {
  name         = "bitnami/mariadb-galera:11.4.4"
  keep_locally = true

  depends_on = [null_resource.docker_network]
}

resource "docker_container" "mariadb" {
  name  = "mariadb-${var.index}"
  image = docker_image.mariadb.image_id

  restart = "unless-stopped"

  # MariaDB Galera ports with IPv6 support
  ports {
    internal = 3306  # MySQL protocol
    external = 3306
    protocol = "tcp"
    ip       = "::"  # IPv6 wildcard
  }

  ports {
    internal = 4567  # Galera Cluster
    external = 4567
    protocol = "tcp"
    ip       = "::"
  }

  ports {
    internal = 4568  # IST
    external = 4568
    protocol = "tcp"
    ip       = "::"
  }

  ports {
    internal = 4444  # SST
    external = 4444
    protocol = "tcp"
    ip       = "::"
  }

  volumes {
    container_path = "/etc/mysql/conf.d/galera.cnf"
    host_path      = local.mariadb_config_file_path
    read_only      = true
  }

  volumes {
    container_path = "/bitnami/mariadb"
    host_path      = local.mariadb_data_dir
  }

  volumes {
    container_path = "/bitnami/mariadb/backup"
    host_path      = "${local.working_dir}/mariadb/backup"
  }

  env = [
    "MARIADB_ROOT_PASSWORD=${var.mariadb_root_password}",
    "MARIADB_DATABASE=${var.mariadb_database}",
    "MARIADB_USER=${var.mariadb_user}",
    "MARIADB_PASSWORD=${var.mariadb_password}",
    "MARIABACKUP_ACCESS_KEY=${var.minio_user}",
    "MARIABACKUP_SECRET_KEY=${var.minio_password}",
    "MARIABACKUP_BUCKET=${var.minio_bucket}",
    "MARIABACKUP_REGION=${var.minio_region}",
    "MARIABACKUP_ENDPOINT=${local.minio_endpoint}",
    "MARIADB_GALERA_CLUSTER_BOOTSTRAP=${var.index == 0 ? "1" : ""}",
    "MARIADB_GALERA_MARIABACKUP_PASSWORD=${var.mariadb_backup_password}"
  ]

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
  }

  depends_on = [
    null_resource.mariadb_configs
  ]

  healthcheck {
    test         = ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${var.mariadb_root_password}"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
