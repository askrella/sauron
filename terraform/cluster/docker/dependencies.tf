resource "null_resource" "healthcheck" {
  depends_on = [
    null_resource.healthcheck_container
  ]

  provisioner "local-exec" {
    command = "echo 'Healthcheck has passed.'"
  }
}

resource "null_resource" "docker_network" {
  depends_on = [
    null_resource.healthcheck,
    docker_network.monitoring,
    docker_network.wan
  ]

  provisioner "local-exec" {
    command = "echo 'Docker network is up and running.'"
  }
}

resource "null_resource" "data_collectors_up" {
  depends_on = [
    null_resource.docker_network,
    docker_container.node_exporter,
    docker_container.cadvisor,
    docker_container.promtail,
    docker_container.tempo
  ]

  provisioner "local-exec" {
    command = "echo 'Data collectors are up and running.'"
  }
}

resource "null_resource" "databases_up" {
  depends_on = [
    docker_container.loki,
    docker_container.prometheus,
    docker_container.tempo,
    null_resource.data_collectors_up
  ]

  provisioner "local-exec" {
    command = "echo 'Databases are up and running.'"
  }
}

resource "null_resource" "grafana_up" {
  depends_on = [
    docker_container.grafana,
    null_resource.databases_up
  ]

  provisioner "local-exec" {
    command = "echo 'Grafana is up and running.'"
  }
}

resource "null_resource" "node_ready" {
  depends_on = [
    null_resource.grafana_up
  ]

  provisioner "local-exec" {
    command = "echo 'Node is ready. Node ID: ${var.index}'"
  }
}

output "node_id" {
  description = "The ID of the node."
  value       = var.index
}
