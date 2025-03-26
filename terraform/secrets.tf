# Create a test secret in Secret Manager
resource "google_secret_manager_secret" "test_secret" {
  secret_id = "audit-test-secret"
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "test_secret_version" {
  secret      = google_secret_manager_secret.test_secret.id
  secret_data = "This is a test secret value"
}

# Grant access to test service account
resource "google_secret_manager_secret_iam_member" "test_secret_access" {
  secret_id = google_secret_manager_secret.test_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.test_sa.email}"
}