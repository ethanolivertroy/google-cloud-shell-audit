# Create test service accounts
resource "google_service_account" "test_sa" {
  account_id   = "audit-test-sa"
  display_name = "Audit Test Service Account"
}

# Create auditor service account for security review
resource "google_service_account" "auditor_sa" {
  account_id   = "security-auditor"
  display_name = "Security Auditor Service Account"
}

# Grant necessary permissions to the auditor
resource "google_project_iam_member" "auditor_roles" {
  for_each = toset([
    "roles/iam.securityReviewer",
    "roles/viewer",
    "roles/cloudasset.viewer", 
    "roles/resourcemanager.organizationViewer"
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.auditor_sa.email}"
}

# Create key for auditor (normally would avoid this, but useful for testing)
resource "google_service_account_key" "auditor_key" {
  service_account_id = google_service_account.auditor_sa.name
}

# Output the key for later use
output "auditor_key" {
  value     = google_service_account_key.auditor_key.private_key
  sensitive = true
}