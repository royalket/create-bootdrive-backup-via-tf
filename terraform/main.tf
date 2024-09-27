# terraform/main.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {}

data "google_project" "current" {}

# Random id for unique naming
resource "random_id" "default" {
  byte_length = 8
}

# Data source to get a list of available VMs
data "google_compute_instance_list" "available_vms" {
  project = data.google_project.current.project_id
}

locals {
  # Select the first available VM
  selected_vm = length(data.google_compute_instance_list.available_vms.instances) > 0 ? data.google_compute_instance_list.available_vms.instances[0] : null
}

# Create a Cloud Storage bucket for backups
resource "google_storage_bucket" "backup_bucket" {
  name     = "vm-backup-bucket-${random_id.default.hex}"
  location = "US"  # You can change this to a specific region if needed
  project  = data.google_project.current.project_id
}

# Create a Cloud Function
resource "google_storage_bucket_object" "function_archive" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.backup_bucket.name
  source = data.archive_file.function_zip.output_path
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/backup"
  output_path = "/tmp/function-source.zip"
}

resource "google_cloudfunctions_function" "backup_function" {
  name        = "vm-backup-function-${random_id.default.hex}"
  description = "Function to backup VM boot disk"
  runtime     = "python39"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.backup_bucket.name
  source_archive_object = google_storage_bucket_object.function_archive.name
  trigger_http          = true
  entry_point           = "create_boot_disk_backup"
  project               = data.google_project.current.project_id

  environment_variables = {
    PROJECT_ID    = data.google_project.current.project_id
    BACKUP_BUCKET = google_storage_bucket.backup_bucket.name
    VM_NAME       = local.selected_vm != null ? local.selected_vm.name : ""
    VM_ZONE       = local.selected_vm != null ? local.selected_vm.zone : ""
  }
}

# Create a Cloud Scheduler job to trigger the function
resource "google_cloud_scheduler_job" "backup_scheduler" {
  name     = "vm-backup-scheduler-${random_id.default.hex}"
  schedule = "0 2 * * *"
  project  = data.google_project.current.project_id

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions_function.backup_function.https_trigger_url

    oidc_token {
      service_account_email = google_service_account.function_invoker.email
    }
  }
}

# Service account for the Cloud Scheduler to invoke the function
resource "google_service_account" "function_invoker" {
  account_id   = "function-invoker-sa-${random_id.default.hex}"
  display_name = "Function Invoker Service Account"
  project      = data.google_project.current.project_id
}

# IAM binding to allow the service account to invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.backup_function.project
  region         = google_cloudfunctions_function.backup_function.region
  cloud_function = google_cloudfunctions_function.backup_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.function_invoker.email}"
}