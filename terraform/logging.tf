# Create a log sink to Cloud Storage
resource "google_logging_project_sink" "storage_sink" {
  name        = "audit-logs-storage-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.logging_bucket.name}"
  
  # Use a filter to only export audit logs
  filter = "logName:\"activity\""

  unique_writer_identity = true
}

# Create a bucket for storing logs
resource "google_storage_bucket" "logging_bucket" {
  name          = "${var.project_id}-logs"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
  
  depends_on = [google_project_service.required_apis]
}

# Grant the log sink's writer identity permission to write to the bucket
resource "google_storage_bucket_iam_member" "log_writer" {
  bucket = google_storage_bucket.logging_bucket.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.storage_sink.writer_identity
}