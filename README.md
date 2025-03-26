# Google Cloud Shell Audit Tool for FedRAMP Compliance

A comprehensive cloud shell script for conducting NIST SP 800-53 Rev5 & FedRAMP compliance assessments and detailed resource inventory on Google Cloud Platform environments.

## Overview

The `gcp_audit.sh` script provides two critical functions:

1. **NIST SP 800-53 Rev5 & FedRAMP Security Compliance Assessment**:
   - Maps checks to specific NIST 800-53 Rev5 controls
   - Evaluates compliance with PASS/WARN/FAIL ratings
   - Covers all major control families (AC, AU, CM, IA, SC, SI, MP, CA, SR, PT)
   - Provides detailed findings with remediation guidance
   - Supports all FedRAMP levels (Low, Moderate, High)
   - Generates evidence packages for auditors

2. **Thorough GCP Resource Inventory**:
   - Catalogs resources across 35+ GCP services
   - Captures configuration details relevant to security
   - Scans both regional and global resources
   - Leverages Cloud Asset Inventory for comprehensive discovery
   - Documents all discovered assets in a structured format

## Features

- **Modular Structure**: Separate functions for compliance checks and inventory
- **Flexible Outputs**: JSON, CSV, HTML, Security Command Center and SSP reporting formats
- **Comprehensive Coverage**: Examines IAM, networking, storage, compute, serverless, containers, and more
- **Organization/Project Awareness**: Handles both org-level and project-level checks
- **Automated Analysis**: Evaluates configurations against security best practices
- **User-Friendly Experience**: Interactive prompts, progress indicators, and clear results
- **Exportable Results**: Generates a ZIP archive with timestamped results
- **Parallel Processing**: Runs checks concurrently for improved performance
- **Differential Scanning**: Compare results between scans to track changes
- **Evidence Collection**: Comprehensive artifacts for compliance assessment
- **SSP Generation**: Creates System Security Plan templates with control implementations

## Quick Start

### Running in Google Cloud Shell (Recommended)

This script is designed to run directly in Google Cloud Shell for maximum compatibility:

```bash
# Open Google Cloud Shell at https://shell.cloud.google.com/

# Clone the repository
git clone https://github.com/yourusername/google-cloud-shell-audit.git
cd google-cloud-shell-audit

# Make the script executable
chmod +x gcp_audit.sh

# Run the script with the default project
./gcp_audit.sh

# Run with specific options
./gcp_audit.sh --project my-project-id --format html --verbose --level high

# When complete, download the results
cloudshell download gcp_audit_results_*.zip
```

### Running Locally

If you prefer to run the script locally:

```bash
# Ensure you have gcloud CLI installed and configured
# https://cloud.google.com/sdk/docs/install

# Clone the repository
git clone https://github.com/yourusername/google-cloud-shell-audit.git
cd google-cloud-shell-audit

# Make the script executable
chmod +x gcp_audit.sh

# Authenticate with GCP
gcloud auth login

# Run the script
./gcp_audit.sh --project my-project-id
```

## Enhanced Usage

```bash
./gcp_audit.sh [options]

Options:
  -h, --help                  Show this help message and exit
  -o, --organization ID       Specify the organization ID (optional)
  -p, --project ID            Specify the project ID (default: current project)
  -a, --all-projects          Scan all accessible projects
  -f, --format FORMAT         Output format: json, csv, html, scc, ssp (default: json)
  -v, --verbose               Enable verbose output
  -r, --report-only           Run only compliance reporting
  -i, --inventory-only        Run only resource inventory
  -d, --diff PREVIOUS_SCAN    Compare with previous scan results
  -j, --jobs NUM              Number of parallel jobs (default: 10)
  -l, --level LEVEL           FedRAMP level: low, moderate, high (default: moderate)
  -c, --custom-controls FILE  Path to custom controls JSON file
  -s, --skip CATEGORIES       Comma-separated list of categories to skip
  -e, --export-evidence       Generate exportable evidence for auditors
  -z, --severity              Include severity ratings in findings
  --ssp-template              Generate System Security Plan template with evidence

Examples:
  ./gcp_audit.sh --organization 123456789012 --format html --verbose --level high
  ./gcp_audit.sh --project my-project-id --inventory-only
  ./gcp_audit.sh --project my-project-id --diff gcp_audit_results_20231201120000 --export-evidence
```

## Compliance Checks

The script performs checks across the following control families:

| Control Family | Description | Examples |
|----------------|-------------|----------|
| Access Control (AC) | Controls related to account management, access enforcement | Service accounts, admin roles, public resources |
| Audit and Accountability (AU) | Controls for logging, monitoring, retention | Audit logging, log retention |
| Configuration Management (CM) | Controls for baseline configurations | Shielded VMs, secure configurations |
| Identification & Authentication (IA) | Controls for authentication, credential management | Key rotation, authentication methods |
| System & Communications Protection (SC) | Controls for boundary protection, cryptography | Network security, encryption, TLS |
| System & Information Integrity (SI) | Controls for flaw remediation, monitoring | Vulnerability management, integrity monitoring |
| Media Protection (MP) | Controls for data protection | Storage bucket security |
| Security Assessment (CA) | Controls for assessment and authorization | Continuous monitoring |
| Supply Chain Risk Management (SR) | Controls for supply chain protection | Binary Authorization, Artifact Registry |
| Privacy Controls (PT) | Controls for PII and data protection | DLP scanning, sensitive data discovery |

## Modern GCP Services Covered

- **VPC Service Controls**: Configuration assessment
- **Binary Authorization**: Container security validation
- **Confidential Computing**: VM and GKE protection
- **Assured Workloads**: Regulatory compliance validation
- **Cloud Asset Inventory**: Complete resource discovery
- **Data Loss Prevention**: PII protection checks
- **Identity-Aware Proxy**: Zero-trust access controls
- **Security Command Center**: Threat detection configuration
- **Workload Identity**: Service authentication validation
- **Organization Policy**: Constraint verification
- **Access Approval**: Admin access validation
- **NIST SP 800-190**: Comprehensive container security compliance validation
  - Image security (vulnerability scanning, configuration, base image sourcing)
  - Container runtime security (vulnerability monitoring, resource limitations, privilege restrictions)
  - Orchestrator security (authentication, authorization, segmentation, mTLS, admission controllers)
  - Host OS security (hardening, access restrictions)
  - Container supply chain security (build pipeline security, vulnerability scanning)
  - Runtime application self-protection (RASP) for containers
  - Container-specific logging and monitoring
  - Container network policy enforcement
  - Container secrets management
  - Container-specific incident response

## Exported Evidence and Configuration Data

The script exports comprehensive configuration data and evidence artifacts specifically designed for auditor examination:

### Standard Exports (Always Included)

1. **Resource Configuration Inventory**:
   - Complete JSON exports of all resource configurations
   - Detailed IAM policies and permissions
   - Network, compute, and storage configurations
   - Full service account details
   - Organization policies
   - KMS keys and encryption settings

2. **Compliance Assessment**:
   - Detailed findings mapped to NIST 800-53 Rev5 controls
   - Control family coverage metrics
   - FedRAMP severity ratings
   - Technical evidence supporting each finding
   - Remediation recommendations with specific steps

### Enhanced Evidence Collection (with `--export-evidence` flag)

When run with the `--export-evidence` flag, additional artifacts are collected:

1. **Control-Specific Evidence**:
   - Organized by control family (AC, AU, CM, etc.)
   - Configuration snapshots supporting each control
   - Direct command outputs from assessment checks
   - Traceable timestamp for each evidence artifact
   - Dedicated NIST SP 800-190 container security evidence section with:
     - Container image vulnerability scanning results
     - Container runtime security configurations and privilege control evidence
     - GKE cluster security settings
     - Orchestrator security evidence including mTLS configuration
     - Kubernetes admission controller policies and configurations
     - Host OS hardening evidence
     - Pod Security Standards implementation details
     - Container supply chain security artifacts
     - Runtime Application Self-Protection (RASP) evidence
     - Container-specific logging and monitoring configurations
     - Container network policy enforcement details
     - Container secrets management implementation
     - Container incident response capabilities

2. **FedRAMP Documentation Artifacts**:
   - Control coverage summaries formatted for FedRAMP packages
   - Configurations in assessment-ready format
   - Direct exports for supporting documentation

### System Security Plan Generation (with `--ssp-template` flag)

When using the SSP template option:

1. **Control Implementation Statements**:
   - Pre-populated control documentation templates
   - Actual configuration evidence linked to controls
   - Implementation details for each control family
   - Gap analysis for missing controls
   - Comprehensive NIST SP 800-190 container security implementation details including:
     - Container image security controls
     - Container runtime security controls
     - Container orchestration security controls
     - Host OS security controls
     - Container supply chain security controls
     - Runtime application self-protection controls
     - Container logging and monitoring controls
     - Container network security controls
     - Container secrets management controls
     - Container incident response controls

### Output Structure

When run, the script creates:

1. A timestamped directory containing all results
2. Structured subdirectories by resource type and control family
3. Evidence packages in appropriate formats for auditor review
4. A consolidated ZIP archive for easy transfer

All outputs are deliberately formatted to support:
- Third-party auditor examination
- Documentation for certification packages (FedRAMP, FISMA, etc.)
- Evidence retention for compliance demonstration

## Prerequisites

When running in Google Cloud Shell:
- No additional software installation required (Cloud Shell has all prerequisites)
- Appropriate permissions to view resources in the target GCP project/organization
- Active Google Cloud account with proper IAM permissions

When running locally:
- Google Cloud SDK (gcloud) installed and configured
- bash, jq, and parallel (will be installed automatically if missing)
- Active authentication to Google Cloud with appropriate permissions

### Required IAM Permissions

#### Recommended Role for Auditors

For security auditors running this script, the recommended role is:

**`roles/iam.securityReviewer`**

This role is specifically designed for security auditing and provides read-only access to all security configurations without any modify permissions. It's ideal for compliance assessments and security reviews.

To assign this role to an auditor:

```bash
# Project level
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=user:auditor@example.com \
  --role=roles/iam.securityReviewer

# Organization level
gcloud organizations add-iam-policy-binding ORGANIZATION_ID \
  --member=user:auditor@example.com \
  --role=roles/iam.securityReviewer
```

#### Additional Roles for Comprehensive Scanning

For complete scanning capabilities, consider adding these read-only roles:

1. **`roles/resourcemanager.organizationViewer`** - Required for organization-level scans
2. **`roles/cloudasset.viewer`** - Needed for Cloud Asset Inventory capabilities
3. **`roles/securitycenter.adminViewer`** - For Security Command Center integration

#### For Standard Users and Administrators

If you're a project owner or administrator running the script:
- `roles/viewer` at the project level is sufficient for basic scans
- Your existing administrative roles likely have all needed permissions

#### Minimum Permissions Custom Role

If you prefer to create a minimal custom role with just the required permissions:

```bash
gcloud iam roles create SecurityAuditor --project=PROJECT_ID \
  --permissions=cloudasset.assets.listResource,cloudasset.assets.searchAllResources,iam.policy.get,resourcemanager.hierarchyNodes.listEffectiveIamPolicies,securitycenter.assets.list,securitycenter.findings.list,securitycenter.sources.list
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.