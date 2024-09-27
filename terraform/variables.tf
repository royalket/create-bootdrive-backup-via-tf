# terraform/variables.tf

variable "project_id" {
  description = "The GCP project ID"
}

variable "region" {
  description = "The region to deploy resources"
  default     = "us-central1"
}

variable "zone" {
  description = "The zone where the existing VM is located"
}

variable "existing_vm_name" {
  description = "The name of the existing VM to backup"
}