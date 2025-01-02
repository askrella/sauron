terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.49.1"
    }
  }
}

variable "hcloud_token" {
  sensitive = true
  description = "The Hetzner Cloud API token"

  validation {
    condition = length(var.hcloud_token) > 0
    error_message = "The Hetzner Cloud API token must be a non-empty string"
  }
}

variable "cluster_name" {
  type = string
  description = "The name of the cluster"

  validation {
    condition = length(var.cluster_name) > 0
    error_message = "The cluster name must be a non-empty string"
  }
}

variable "server_count" {
  type = number
  default = 1

  validation {
    condition = var.server_count > 0
    error_message = "The server count must be greater than 0"
  }
}

variable "location" {
  type = string
  default = "fsn1"
  description = "The location of the server according to https://docs.hetzner.com/cloud/general/locations"

  validation {
    condition = contains(["fsn1", "nbg1", "hel1", "ber1"], var.location)
    error_message = "The location must be a valid Hetzner Cloud location"
  }
}

variable "server_type" {
  type = string
  default = "cax11"
  description = "The type of the server according to https://docs.hetzner.com/cloud/general/server-types"

  validation {
    condition = can(regex("c(?:a|x)?x([0-9]{1,2})", var.server_type))
    error_message = "The server type must be a valid Hetzner Cloud server type"
  }
}

variable "image" {
  type = string
  default = "ubuntu-24.04"

  validation {
    condition = length(var.image) > 0
    error_message = "The image name must be a non-empty string"
  }
}

variable "server_prefix" {
  type = string
  description = "(optional) The prefix of the server name."
}

provider "hcloud" {
  token = var.hcloud_token
}

locals {
  labels = {
    cluster_name = var.cluster_name
  }
}

# Server Definition

resource "hcloud_server" "server" {
  for_each = { for i in range(var.server_count) : i => i }
  name = "${var.server_prefix}-${each.value}"
  image = var.image
  location = var.location
  server_type = var.server_type
  ssh_keys = [hcloud_ssh_key.main.id]

  # Allows downsizing the server
  keep_disk = true

  user_data = file("./hetzner_server/cloud-init")

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.network.id
    ip = "10.0.0.${each.value + 2}"
  }

  labels = local.labels

  firewall_ids = [hcloud_firewall.cluster_firewall.id]

  depends_on = [hcloud_network.network, hcloud_network_subnet.subnet]
}

# Network Definition

resource "hcloud_network" "network" {
  name     = "${var.cluster_name}-net"
  ip_range = "10.0.0.0/8"

  labels = local.labels
}

resource "hcloud_network_subnet" "subnet" {
  network_id = hcloud_network.network.id
  type       = "cloud"
  network_zone = "eu-central"
  ip_range   = "10.0.0.0/8"
}

# SSH Key Definition

resource "hcloud_ssh_key" "main" {
  name       = "${var.cluster_name}-ssh-key"
  public_key = file("./id_ed25519.pub")
}

# Firewall Definition

resource "hcloud_firewall" "cluster_firewall" {
  name = "${var.cluster_name}-firewall"
  
  # ==== Private Access ====

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "10900-10910"
    description = "Thanos"

    source_ips = [
      hcloud_network_subnet.subnet.ip_range
    ]
  }

  # Loki web
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "3100"
    description = "Loki HTTP"
    source_ips = [
      hcloud_network_subnet.subnet.ip_range
    ]
  }

  # Loki gRPC
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "7946"
    description = "Loki gRPC"
    source_ips = [
      hcloud_network_subnet.subnet.ip_range
    ]
  } 
  
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "7956"
    description = "Tempo gRPC"
    source_ips = [
      hcloud_network_subnet.subnet.ip_range
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "4417"
    description = "Tempo gRPC"
    source_ips = [
      hcloud_network_subnet.subnet.ip_range
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "4418"
    description = "Tempo gRPC"
    source_ips = [
      hcloud_network_subnet.subnet.ip_range
    ]
  }

  # ==== Public Access ====

  # SSH Access
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    description = "SSH"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Grafana
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "3000"
    description = "Grafana"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # ICMP (ping)
  rule {
    direction = "in"
    protocol  = "icmp"
    description = "ICMP"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  labels = local.labels
}

# Validation

resource "null_resource" "ssh_check" {
  for_each = hcloud_server.server

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to finish'",
      "timeout 120 bash -c 'while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done'",  # Wait for cloud-init to finish with timeout
      "echo 'Waiting for docker to be available'",
      "timeout 120 bash -c 'until docker info &>/dev/null; do sleep 1; done'",  # Wait for docker service to be running
      "echo 'Running hello-world'",
      "docker run --rm hello-world",
      "echo 'SSH connection test for Hetzner Cloud server creation successful on ${each.value.name}'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      host        = each.value.ipv6_address
      private_key = file("./id_ed25519")
    }
  }

  triggers = {
    always = timestamp()
  }

  depends_on = [hcloud_server.server]
}

# Outputs

output "server_ipv4_addresses" {
  value = [for server in hcloud_server.server : one(server.network).ip]
}

output "server_ipv6_addresses" {
  value = values(hcloud_server.server)[*].ipv6_address
}

output "server_names" {
  value = values(hcloud_server.server)[*].name
}
