# functions/backup/main.py

import os
from google.cloud import compute_v1
from google.cloud import storage

PROJECT_ID = os.environ.get('PROJECT_ID')
BACKUP_BUCKET = os.environ.get('BACKUP_BUCKET')

def create_boot_disk_backups(request):
    """Cloud Function to create boot disk backups for all VMs in the project."""
    instance_client = compute_v1.InstancesClient()
    disk_client = compute_v1.DisksClient()
    
    # List all zones in the project
    zone_client = compute_v1.ZonesClient()
    zones = [zone.name for zone in zone_client.list(project=PROJECT_ID)]

    for zone in zones:
        # List all instances in the zone
        instances = instance_client.list(project=PROJECT_ID, zone=zone)
        
        for instance in instances:
            try:
                # Get the boot disk for the instance
                boot_disk = instance.disks[0]
                
                # Create a snapshot of the boot disk
                snapshot_name = f"{instance.name}-boot-disk-snapshot"
                operation = disk_client.create_snapshot(
                    project=PROJECT_ID,
                    zone=zone,
                    disk=boot_disk.source.split('/')[-1],
                    snapshot_resource=compute_v1.Snapshot(name=snapshot_name)
                )
                operation.result()  # Wait for the operation to complete

                print(f"Created snapshot {snapshot_name} for instance {instance.name} in zone {zone}")

                # Export the snapshot to a file in the backup bucket
                export_name = f"{instance.name}-boot-disk-backup.tar.gz"
                export_operation = disk_client.export(
                    project=PROJECT_ID,
                    zone=zone,
                    snapshot=snapshot_name,
                    export_snapshot_request_resource=compute_v1.ExportSnapshotRequest(
                        storage_locations=[BACKUP_BUCKET],
                        output_uri=f"gs://{BACKUP_BUCKET}/{export_name}"
                    )
                )
                export_operation.result()  # Wait for the export to complete

                print(f"Exported snapshot to gs://{BACKUP_BUCKET}/{export_name}")

            except Exception as e:
                print(f"An error occurred during the backup process for instance {instance.name} in zone {zone}: {str(e)}")

    return "Boot disk backup process completed for all VMs", 200