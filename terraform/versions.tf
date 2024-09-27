# terraform/versions.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  required_version = ">= 0.14"
}

provider "google" {
  project = data.google_project.current.project_id
  region  = var.region
}