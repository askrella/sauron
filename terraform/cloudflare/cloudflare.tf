variable "domain" {
  type        = string
  description = "The domain name to create the load balancer for"
}

variable "ipv6_addresses" {
  type        = list(string)
  description = "List of IPv6 addresses to load balance between"
}

# Create monitor to check health of backends
resource "cloudflare_load_balancer_monitor" "monitor" {
  description = "Health check for monitoring cluster nodes"
  type        = "http"
  port        = 3000 # Grafana port
  method      = "GET"
  path        = "/api/health"
  expected_codes = "200"
  interval    = 60
  retries     = 2
  timeout     = 5
}

# Create pool of backend servers
resource "cloudflare_load_balancer_pool" "pool" {
  name = "monitoring-cluster-pool"
  monitor = cloudflare_load_balancer_monitor.monitor.id
  
  dynamic "origins" {
    for_each = var.ipv6_addresses
    content {
      name    = "node-${index(var.ipv6_addresses, origins.value)}"
      address = "[${origins.value}]"
      enabled = true
      weight  = 1
    }
  }
}

# Get zone ID for domain
data "cloudflare_zones" "domain" {
  filter {
    name = var.domain
  }
}

# Create load balancer
resource "cloudflare_load_balancer" "lb" {
  zone_id          = data.cloudflare_zones.domain.zones[0].id
  name             = "monitoring.${var.domain}"
  fallback_pool_id = cloudflare_load_balancer_pool.pool.id
  default_pool_id  = cloudflare_load_balancer_pool.pool.id
  enabled          = true
  proxied          = true

  rules {
    name = "default"
    condition = "true"
    fixed_response {
      message_body = "Service Unavailable"
      status_code  = 503
      content_type = "text/plain"
    }
  }
}
