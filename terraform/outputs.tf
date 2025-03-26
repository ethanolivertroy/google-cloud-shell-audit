output "project_id" {
  value       = var.project_id
  description = "The project ID where resources are deployed"
}

output "gke_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "The name of the GKE cluster"
}

output "storage_bucket_name" {
  value       = google_storage_bucket.test_bucket.name
  description = "The name of the test storage bucket"
}

output "vm_instance_name" {
  value       = google_compute_instance.vm_instance.name
  description = "The name of the test VM instance"
}

output "setup_complete" {
  value       = "Test environment setup complete. Use the auditor service account to test the audit script."
  description = "Setup completion message"
}