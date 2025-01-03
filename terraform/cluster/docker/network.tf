
resource "docker_network" "monitoring" {
  name     = "monitoring"
  internal = true
  ipv6     = true
}

resource "docker_network" "wan" {
  name = "wan"
  ipv6 = true
}
