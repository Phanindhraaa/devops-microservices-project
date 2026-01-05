terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "nginx" {
  count = var.container_count
  
  image = docker_image.nginx.image_id
  name  = "terraform-nginx-${count.index + 1}"
  
  ports {
    internal = 80
    external = var.base_port + count.index
  }
}
