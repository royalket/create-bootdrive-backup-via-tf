# terraform/main.tf

data "google_project" "current" {}

data "google_compute_zones" "available" {
  project = data.google_project.current.project_id
  region  = var.region
}

data "google_compute_instances" "available" {
  project = data.google_project.current.project_id
  zone    = data.google_compute_zones.available.names[0]
}

locals {
  selected_vm = length(data.google_compute_instances.available.instances) > 0 ? data.google_compute_instances.available.instances[0] : null
}

resource "google_storage_bucket" "backup_bucket" {
  name     = "vm-backup-bucket-${data.google_project.current.project_id}"
  location = var.region
  project  = data.google_project.current.project_id
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/backup"
  output_path = "/tmp/function-source.zip"
}

resource "google_storage_bucket_object" "function_archive" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.backup_bucket.name
  source = data.archive_file.function_zip.output_path
}

resource "google_cloudfunctions_function" "backup_function" {
  name        = "vm-backup-function"
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

resource "google_cloud_scheduler_job" "backup_scheduler" {
  name     = "vm-backup-scheduler"
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

resource "google_service_account" "function_invoker" {
  account_id   = "function-invoker-sa"
  display_name = "Function Invoker Service Account"
  project      = data.google_project.current.project_id
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.backup_function.project
  region         = google_cloudfunctions_function.backup_function.region
  cloud_function = google_cloudfunctions_function.backup_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.function_invoker.email}"
}