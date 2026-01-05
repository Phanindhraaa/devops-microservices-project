variable "container_count" {
  description = "Number of nginx containers"
  type        = number
  default     = 3
}

variable "base_port" {
  description = "Starting port number"
  type        = number
  default     = 8080
}
