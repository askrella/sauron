terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.49.1"
    }
  }
}

variable "cloudflare_api_token" {
  type        = string
  description = "The API token for the Cloudflare account"
  sensitive   = true
}

variable "cloudflare_account_id" {
  type        = string
  description = "The account ID for the Cloudflare account"
}

variable "base_domain" {
  type        = string
  description = "The base domain name to create the load balancer for, example: example.com"
}

variable "domain" {
  type        = string
  description = "The domain name to create the load balancer for, example: monitoring.example.com"
}

variable "ipv6_addresses" {
  type        = list(string)
  description = "List of IPv6 addresses to load balance between"
}

# Create monitor to check health of backends
resource "cloudflare_load_balancer_monitor" "monitor" {
  description    = "Health check for monitoring cluster nodes"
  type           = "http"
  port           = 80
  method         = "GET"
  path           = "/api/health"
  expected_codes = "200"
  interval       = 60

  account_id = var.cloudflare_account_id
}

resource "cloudflare_load_balancer_pool" "pool" {
  name    = "monitoring-cluster-pool"
  monitor = cloudflare_load_balancer_monitor.monitor.id

  dynamic "origins" {
    for_each = { for i, addr in var.ipv6_addresses : i => addr }
    content {
      name    = "node-${origins.key}"
      address = "node-${origins.key}.${var.domain}"
      header {
        header = "Host"
        values = ["node-${origins.key}.${var.domain}"]
      }
      enabled = true
      weight  = 1
    }
  }

  account_id = var.cloudflare_account_id
}

# Get zone ID for domain
data "cloudflare_zone" "domain" {
  name = var.base_domain
}

resource "cloudflare_record" "monitoring_nodes" {
  count   = length(var.ipv6_addresses)
  zone_id = data.cloudflare_zone.domain.id
  name    = "node-${count.index}.${var.domain}"
  content = var.ipv6_addresses[count.index]
  type    = "AAAA"
  proxied = false
  ttl     = 60
}

# Create load balancer
resource "cloudflare_load_balancer" "lb" {
  zone_id          = data.cloudflare_zone.domain.id
  name             = var.domain
  default_pool_ids    = [cloudflare_load_balancer_pool.pool.id]
  fallback_pool_id    = cloudflare_load_balancer_pool.pool.id
  enabled          = true
  proxied          = true
  session_affinity = "cookie"

  depends_on = [cloudflare_load_balancer_pool.pool]
}
