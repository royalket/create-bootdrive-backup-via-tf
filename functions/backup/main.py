# functions/backup/main.py

import os
from google.cloud import compute_v1
from google.cloud import storage

PROJECT_ID = os.environ.get('PROJECT_ID')
BACKUP_BUCKET = os.environ.get('BACKUP_BUCKET')
VM_NAME = os.environ.get('VM_NAME')
VM_ZONE = os.environ.get('VM_ZONE')

def create_boot_disk_backup(request):
    """Cloud Function to create boot disk backup for a specific VM."""
    if not VM_NAME or not VM_ZONE:
        print("No VM found in the project. Backup cannot be performed.")
        return "No VM available for backup", 400

    instance_client = compute_v1.InstancesClient()
    disk_client = compute_v1.DisksClient()

    try:
        # Get the specified instance
        instance = instance_client.get(project=PROJECT_ID, zone=VM_ZONE, instance=VM_NAME)
        
        # Get the boot disk for the instance
        boot_disk = instance.disks[0]
        
        # Create a snapshot of the boot disk
        snapshot_name = f"{VM_NAME}-boot-disk-snapshot"
        operation = disk_client.create_snapshot(
            project=PROJECT_ID,
            zone=VM_ZONE,
            disk=boot_disk.source.split('/')[-1],
            snapshot_resource=compute_v1.Snapshot(name=snapshot_name)
        )
        operation.result()  # Wait for the operation to complete

        print(f"Created snapshot {snapshot_name} for instance {VM_NAME}")

        # Export the snapshot to a file in the backup bucket
        export_name = f"{VM_NAME}-boot-disk-backup.tar.gz"
        export_operation = disk_client.export(
            project=PROJECT_ID,
            zone=VM_ZONE,
            snapshot=snapshot_name,
            export_snapshot_request_resource=compute_v1.ExportSnapshotRequest(
                storage_locations=[BACKUP_BUCKET],
                output_uri=f"gs://{BACKUP_BUCKET}/{export_name}"
            )
        )
        export_operation.result()  # Wait for the export to complete

        print(f"Exported snapshot to gs://{BACKUP_BUCKET}/{export_name}")

        return "Boot disk backup process completed", 200
    except Exception as e:
        print(f"An error occurred during the backup process: {str(e)}")
        return f"Backup failed: {str(e)}", 500