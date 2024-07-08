terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.32.0"
    }
  #   consul = {
  #     source = "hashicorp/consul"
  #     version = "2.20.0"
  #   }
    hcp = {
      source = "hashicorp/hcp"
      version = "0.87.1"
    }
  }
}


provider "google" {
  project = var.gcp_project
  region = var.gcp_region
}