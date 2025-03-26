# Create Cloud Storage bucket
resource "google_storage_bucket" "test_bucket" {
  name          = "${var.project_id}-storage"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true

  depends_on = [google_project_service.required_apis]
}

# Add test file to bucket
resource "google_storage_bucket_object" "test_object" {
  name    = "test-file.txt"
  bucket  = google_storage_bucket.test_bucket.name
  content = "This is a test file for security audit checking."
}