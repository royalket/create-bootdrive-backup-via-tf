# terraform/outputs.tf

output "selected_vm_name" {
  value       = local.selected_vm != null ? local.selected_vm.name : "No VM found"
  description = "The name of the selected VM for backup"
}

output "backup_bucket_name" {
  value       = google_storage_bucket.backup_bucket.name
  description = "The name of the backup storage bucket"
}

output "backup_function_name" {
  value       = google_cloudfunctions_function.backup_function.name
  description = "The name of the backup Cloud Function"
}

output "backup_scheduler_name" {
  value       = google_cloud_scheduler_job.backup_scheduler.name
  description = "The name of the backup scheduler job"
}