# Create Compute Engine instance
resource "google_compute_instance" "vm_instance" {
  name         = "audit-test-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      // This creates an ephemeral external IP
    }
  }

  # Required for test OS compliance checks
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [google_project_service.required_apis]
}