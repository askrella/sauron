variable "server_ipv6_addresses" {
  type        = list(string)
  description = "List of IPv6 addresses of the servers"

  validation {
    condition = alltrue([
      for ipv6 in var.server_ipv6_addresses : can(regex("^[0-9a-fA-F:]+$", ipv6))
    ])
    error_message = "Invalid IPv6 address format."
  }
}

variable "server_ipv4_addresses" {
  type        = list(string)
  description = "List of IPv4 addresses of the servers"

  validation {
    condition = alltrue([
      for ipv4 in var.server_ipv4_addresses : can(regex("^[0-9.]+$", ipv4))
    ])
    error_message = "Invalid IPv4 address format."
  }
}

variable "otel_collector_username" {
  description = "The username for the OTel collector"
  type        = string
}

variable "otel_collector_password" {
  description = "The bcrypt hashed password for the OTel collector"
  type        = string
  sensitive   = true
}

variable "domain" {
  type        = string
  description = "The domain name used for accessing the cluster: monitoring.example.com"
}

variable "cluster_size" {
  type        = number
  description = "The size of the cluster"
}

variable "ssh_absolute_key_path" {
  type        = string
  description = "The absolutepath to the SSH key to use for the Docker provider"
}

variable "gf_server_root_url" {
  type        = string
  description = "The root URL for Grafana"
}

variable "gf_auth_google_client_id" {
  type        = string
  description = "Google OAuth client ID"
}

variable "gf_auth_google_client_secret" {
  type        = string
  description = "Google OAuth client secret"
  sensitive   = true
}

variable "gf_auth_google_allowed_domains" {
  type        = string
  description = "Allowed domains for Google OAuth"
}

variable "grafana_admin_password" {
  type        = string
  description = "Password for the Grafana admin user"
  sensitive   = true
}

variable "minio_bucket" {
  type        = string
  description = "The MinIO bucket name"
}

variable "minio_user" {
  type        = string
  description = "The MinIO user"
}

variable "minio_password" {
  type        = string
  description = "The MinIO password"
  sensitive   = true
}

variable "minio_region" {
  type        = string
  description = "The MinIO region"
}

variable "mariadb_root_password" {
  type        = string
  description = "The root password for MariaDB"
  sensitive   = true
}

variable "mariadb_backup_password" {
  type        = string
  description = "The password for the MariaDB backup user"
  sensitive   = true
}

variable "mariadb_database" {
  type        = string
  description = "The name of the MariaDB database to create"
}

variable "mariadb_user" {
  type        = string
  description = "The name of the MariaDB user to create"
}

variable "mariadb_password" {
  type        = string
  description = "The password for the MariaDB user"
  sensitive   = true
}

resource "local_file" "tfvars" {
  count    = var.cluster_size
  filename = "${path.module}/docker/terraform.tfvars.${count.index}"
  content  = <<-EOT
    server_ipv6_address = "${var.server_ipv6_addresses[count.index]}"
    cluster_ipv6_addresses = ${jsonencode(var.server_ipv6_addresses)}
    cluster_ipv4_addresses = ${jsonencode(var.server_ipv4_addresses)}
    index = ${count.index}
    ssh_key_path = "${var.ssh_absolute_key_path}"
    domain = "${var.domain}"

    otel_collector_username = "${var.otel_collector_username}"
    otel_collector_password = "${replace(replace(var.otel_collector_password, "$$", "$"), "$", "$$")}"
    
    # Grafana Configuration
    grafana_admin_password = "${var.grafana_admin_password}"
    
    # Grafana OAuth Configuration
    gf_server_root_url = "${var.gf_server_root_url}"
    gf_auth_google_enabled = "true"
    gf_auth_google_name = "Google"
    gf_auth_google_client_id = "${var.gf_auth_google_client_id}"
    gf_auth_google_client_secret = "${var.gf_auth_google_client_secret}"
    gf_auth_google_scopes = "openid email profile"
    gf_auth_google_auth_url = "https://accounts.google.com/o/oauth2/v2/auth"
    gf_auth_google_token_url = "https://oauth2.googleapis.com/token"
    gf_auth_google_api_url = "https://openidconnect.googleapis.com/v1/userinfo"
    gf_auth_google_allowed_domains = "${var.gf_auth_google_allowed_domains}"
    gf_auth_google_allow_sign_up = "true"

    mariadb_root_password = "${var.mariadb_root_password}"
    mariadb_backup_password = "${var.mariadb_backup_password}"
    mariadb_database = "${var.mariadb_database}"
    mariadb_user = "${var.mariadb_user}"
    mariadb_password = "${var.mariadb_password}"

    minio_bucket = "${var.minio_bucket}"
    minio_user = "${var.minio_user}"
    minio_password = "${var.minio_password}"
    minio_region = "${var.minio_region}"
  EOT
}

resource "null_resource" "docker_setup" {
  count = var.cluster_size

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export TF_LOG=INFO
      
      # Run init and log
      TF_LOG_PATH="terraform_init.${count.index}.log" \
        terraform -chdir=./cluster/docker init

      # Run plan and log
      TF_LOG_PATH="terraform_plan.${count.index}.log" \
        terraform -chdir=./cluster/docker plan \
          -state=terraform.tfstate.${count.index} \
          -var-file=terraform.tfvars.${count.index} \
          -parallelism=10 \
          -no-color \
          -out=tfplan.${count.index}
      
      # Run apply and log
      TF_LOG_PATH="terraform_apply.${count.index}.log" \
        terraform -chdir=./cluster/docker apply -auto-approve \
          -state=terraform.tfstate.${count.index} \
          -var-file=terraform.tfvars.${count.index} \
          -parallelism=1 \
          -no-color \
          tfplan.${count.index}
    EOT
    # -parallelism=1 is a workaround for ssh connection issues: https://github.com/kreuzwerker/terraform-provider-docker/issues/262
    # Setting a higher value makes this extremely unstable
  }

  triggers = {
    timestamp = timestamp()
  }
}
