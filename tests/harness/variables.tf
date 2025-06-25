variable "is_local_test_environment" {
  description = "If true, enables self-signed TLS, local networking, and disables public DNS dependencies."
  type        = bool
  default     = false
} 