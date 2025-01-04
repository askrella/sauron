resource "docker_image" "thanos" {
    name         = "quay.io/thanos/thanos:v0.37.2"
    keep_locally = true

    depends_on = [
        null_resource.docker_network
    ]
} 