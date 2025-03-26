# GCP Audit Development Environment Setup

This document guides you through setting up a development environment for the Google Cloud Shell Audit tool. This setup includes:

1. Creating a test GCP project
2. Deploying sample infrastructure for testing
3. Configuring IAM permissions for security audits
4. Setting up the development environment
5. Testing the script against the deployed infrastructure

## Prerequisites

Before you begin, you'll need:

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed
- [Terraform](https://www.terraform.io/downloads) installed (version ≥ 1.0.0)
- A Google Cloud Platform account with billing enabled
- Editor/Owner permissions in your organization (to create projects and set up permissions)

## 1. Development Environment Setup

### Clone the Repository

```bash
git clone https://github.com/yourusername/google-cloud-shell-audit.git
cd google-cloud-shell-audit
```

### Install Required Tools

Ensure you have the required tools for script development:

```bash
# Install jq for JSON processing
sudo apt-get update && sudo apt-get install -y jq parallel

# Authenticate with Google Cloud
gcloud auth login
```

## 2. Create Test Infrastructure with Terraform

We'll use Terraform to create a test GCP environment that includes resources commonly found in enterprise environments.

### Create a Test Project

```bash
# Create a new project for testing
export PROJECT_ID="audit-script-test-$(date +%s | cut -c 6-13)"
gcloud projects create $PROJECT_ID --name="Audit Script Test"

# Link the project to your billing account
gcloud billing projects link $PROJECT_ID --billing-account=YOUR_BILLING_ACCOUNT_ID

# Set the project as the default
gcloud config set project $PROJECT_ID
```

### Initialize Terraform

Create a `terraform` directory in the repository:

```bash
mkdir -p terraform
cd terraform
```

### Create Terraform Files

Create the following Terraform files to set up test infrastructure.

#### `provider.tf`

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
```

#### `variables.tf`

```hcl
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for resources"
  type        = string
  default     = "us-central1-a"
}

variable "enable_apis" {
  description = "Whether to enable APIs in the project"
  type        = bool
  default     = true
}
```

#### `apis.tf`

```hcl
# Enable required GCP APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "containeranalysis.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "securitycenter.googleapis.com",
    "storage.googleapis.com",
    "binaryauthorization.googleapis.com",
    "artifactregistry.googleapis.com",
    "dlp.googleapis.com",
    "iap.googleapis.com"
  ])

  project = var.project_id
  service = each.key

  disable_dependent_services = false
  disable_on_destroy         = false

  count = var.enable_apis ? 1 : 0
}
```

#### `network.tf`

```hcl
# Create VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "audit-test-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required_apis]
}

# Create subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "audit-test-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id

  private_ip_google_access = true
  
  # Add secondary IP range for GKE pods
  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = "10.1.0.0/16"
  }
  
  # Add secondary IP range for GKE services
  secondary_ip_range {
    range_name    = "service-range"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# Create firewall rule
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24"]
}
```

#### `compute.tf`

```hcl
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
```

#### `storage.tf`

```hcl
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
```

#### `gke.tf`

```hcl
# Create GKE cluster
resource "google_container_cluster" "primary" {
  name     = "audit-test-gke-cluster"
  location = var.zone

  # Use a regional cluster for real workloads
  # location = var.region
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.subnet.id

  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Configuration for master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "all-for-testing"
    }
  }

  # IP allocation policy
  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-range"
    services_secondary_range_name = "service-range"
  }

  # Enable network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Enable shielded nodes
  node_config {
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Create separately managed node pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "audit-test-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "e2-standard-2"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable workload identity on this node pool
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Enable shielded nodes features
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_container_cluster.primary]
}

# Create service account for GKE nodes
resource "google_service_account" "gke_sa" {
  account_id   = "gke-node-sa"
  display_name = "GKE Node Service Account"
}

# Grant necessary permissions to GKE service account
resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer"
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}
```

#### `iam.tf`

```hcl
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
```

#### `secrets.tf`

```hcl
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
```

#### `logging.tf`

```hcl
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
```

#### `outputs.tf`

```hcl
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
```

#### `terraform.tfvars.example`

```hcl
project_id  = "audit-script-test-12345678"
region      = "us-central1"
zone        = "us-central1-a"
enable_apis = true
```

### Deploy the Infrastructure

```bash
# Copy and edit the example vars file
cp terraform.tfvars.example terraform.tfvars
# Edit the terraform.tfvars file with your project ID

# Initialize Terraform
terraform init

# Preview the changes
terraform plan

# Apply the changes
terraform apply
```

## 3. Testing the Audit Script

After deploying the test infrastructure, you can test the audit script against it.

### Prerequisites for Testing

- Wait for all GCP resources to fully provision (5-10 minutes after Terraform completes)
- Ensure all APIs are enabled and resources are created

### Test as Service Account

To test the script as the auditor service account:

```bash
# Get the service account key from Terraform output
terraform output -raw auditor_key | base64 --decode > auditor_key.json

# Authenticate as the service account
gcloud auth activate-service-account --key-file=auditor_key.json

# Set project
gcloud config set project $(terraform output -raw project_id)

# Run the audit script
cd ..
./gcp_audit.sh --project $(terraform output -raw project_id) --format html --verbose --export-evidence --level moderate
```

### Test in Cloud Shell

You can also test directly in Google Cloud Shell:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your test project
3. Open Cloud Shell
4. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/google-cloud-shell-audit.git
   cd google-cloud-shell-audit
   chmod +x gcp_audit.sh
   ```
5. Run the script:
   ```bash
   ./gcp_audit.sh --format html --verbose --export-evidence --level moderate
   ```

## 4. Clean Up

When you're done testing, clean up the resources to avoid incurring charges:

```bash
# Go to terraform directory
cd terraform

# Destroy all resources
terraform destroy

# Or delete the entire project
gcloud projects delete $PROJECT_ID
```

## Next Steps

- Review the audit results and compare them to the infrastructure deployed
- Modify the script as needed based on test results
- Consider additional test scenarios by modifying the Terraform code