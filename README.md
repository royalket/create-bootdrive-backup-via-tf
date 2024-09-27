# VM Backup Demo Project

This project demonstrates how to create a VM in Google Cloud Platform and set up an automated backup system for its boot disk using Cloud Functions and Cloud Scheduler.

## Prerequisites

1. A Google Cloud Platform account
2. Terraform installed on your local machine
3. `gcloud` CLI tool installed and configured

## Setup

1. Clone this repository to your local machine.
2. Navigate to the `terraform` directory.
3. Create a `terraform.tfvars` file with the following content:
   ```
   project_id = "your-gcp-project-id"
   ```
4. Run the following commands:
   ```
   terraform init
   terraform plan
   terraform apply
   ```

## What this does

1. Creates a Compute Engine VM instance
2. Sets up a Cloud Storage bucket for backups
3. Deploys a Cloud Function that creates and exports boot disk snapshots
4. Configures a Cloud Scheduler job to trigger the backup function daily

## Cleaning up

To remove all resources created by this project, run:

```
terraform destroy
```

## Note

This is a demo project and may need additional security considerations for production use.