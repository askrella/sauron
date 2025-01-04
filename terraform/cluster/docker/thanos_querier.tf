locals {
  thanos_querier_label = "thanos-query-${var.index}"
}

resource "docker_container" "thanos_querier" {
  name  = "thanos-query-${var.index}"
  image = docker_image.thanos.image_id

  restart = "unless-stopped"

  labels {
    label = "pod"
    value = local.thanos_querier_label
  }

  command = concat([
    "query",
    "--http-address=0.0.0.0:10904",
    "--grpc-address=0.0.0.0:10903",
    "--store=thanos-sidecar-${var.index}:10901", # Connect to sidecar
    "--store=thanos-store-${var.index}:10905"    # Connect to store gateway
    ],
    # Add store endpoints for other nodes in cluster
    [for ip in local.other_server_ips : "--store=[${ip}]:10901"]
  )

  ports {
    internal = 10903
    external = 10903
    protocol = "tcp"
  }

  ports {
    internal = 10904
    external = 10904
    protocol = "tcp"
  }

  healthcheck {
    test         = ["CMD", "wget", "--spider", "http://localhost:10904/-/healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  networks_advanced {
    name = docker_network.wan.name
  }

  user = "65534" # nobody user

  log_opts = {
    max-size = "10m"
    max-file = "3"
  }

  security_opts = [
    "no-new-privileges:true"
  ]

  depends_on = [
    docker_container.thanos_sidecar,
    docker_container.thanos_store
  ]

  lifecycle {
    # Fix for re-deployment due to network_mode change
    ignore_changes = [network_mode]
  }
}
