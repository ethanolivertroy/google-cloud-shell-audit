# FedRAMP Compliance Testing Guide

This document provides guidance on testing the FedRAMP compliance assessment capabilities of the GCP Audit Script, including evidence collection for auditors and SSP documentation generation.

## Prerequisites

Before testing the FedRAMP compliance capabilities, ensure you have:

1. Completed the environment setup described in `setup.md`
2. Deployed the test infrastructure using Terraform
3. Access to a Google Cloud project with FedRAMP-relevant services

## FedRAMP Compliance Levels

The audit script supports three FedRAMP impact levels:

- **Low**: Basic security controls for non-sensitive data
- **Moderate**: Enhanced security controls for sensitive data (most common level)
- **High**: Stringent security controls for highly sensitive data

## Testing FedRAMP Evidence Collection

The audit script can generate FedRAMP-specific evidence and documentation across all control families. This section guides you through testing these capabilities.

### Step 1: Run the Audit with FedRAMP Evidence Collection

Execute the audit script with FedRAMP-specific parameters:

```bash
# For Moderate impact level (most common)
./gcp_audit.sh --project $PROJECT_ID --format html --export-evidence --level moderate

# For Low impact level
./gcp_audit.sh --project $PROJECT_ID --format html --export-evidence --level low

# For High impact level
./gcp_audit.sh --project $PROJECT_ID --format html --export-evidence --level high
```

### Step 2: Examine the Generated Evidence

After running the audit, examine the FedRAMP evidence collection:

```bash
cd gcp_audit_results_*/fedramp_evidence
```

The directory structure should include:

```
fedramp_evidence/
├── AC/               # Access Control
├── AU/               # Audit and Accountability
├── CA/               # Assessment, Authorization, and Monitoring
├── CM/               # Configuration Management
├── ContainerSecurity/# NIST SP 800-190 container security
├── CP/               # Contingency Planning
├── IA/               # Identification and Authentication
├── IR/               # Incident Response
├── MA/               # Maintenance
├── MP/               # Media Protection
├── PE/               # Physical and Environmental Protection
├── PL/               # Planning
├── PS/               # Personnel Security
├── RA/               # Risk Assessment
├── SA/               # System and Services Acquisition
├── SC/               # System and Communications Protection
├── SI/               # System and Information Integrity
├── SR/               # Supply Chain Risk Management
├── SSP/              # System Security Plan statements
└── evidence_index.md # Evidence index file
```

Each control family directory contains evidence mapped to specific controls based on the selected impact level.

### Step 3: Verify Control Coverage

Check that controls are properly mapped across impact levels:

1. **Low Impact Controls**: Should include basic controls with `-L` suffix
2. **Moderate Impact Controls**: Should include both `-L` and `-M` suffix controls
3. **High Impact Controls**: Should include `-L`, `-M`, and `-H` suffix controls

Use the following commands to verify control coverage:

```bash
# Verify control coverage for Access Control (AC)
find ./AC -name "*.md" | sort

# Count controls by impact level
find ./AC -name "AC-*-L*.md" | wc -l
find ./AC -name "AC-*-M*.md" | wc -l
find ./AC -name "AC-*-H*.md" | wc -l
```

### Step 4: Check Control Evidence Artifacts

Examine individual control evidence files to ensure they contain:

1. Control information and metadata
2. Implementation evidence
3. Technical configuration details
4. GCP-specific implementation notes

Example:

```bash
cat ./AC/AC-2.md
```

### Step 5: Verify SSP Templates

Examine the System Security Plan (SSP) implementation statements:

```bash
cd SSP
```

Check that the SSP templates include:

1. Control implementation statements for each family
2. Specific implementation details based on actual configurations
3. Container security mappings to FedRAMP controls
4. FedRAMP level-specific controls

Example:

```bash
cat AC_Implementation.md
cat NIST_800-190_Implementation.md
```

## Testing FedRAMP SSP Generation

The audit script can also generate a complete System Security Plan (SSP) template in a format compatible with FedRAMP documentation requirements.

To test this functionality:

```bash
./gcp_audit.sh --project $PROJECT_ID --format ssp --level moderate
```

This should generate a structured SSP template that maps implementation details to FedRAMP controls.

## Verifying Differential Scanning

The audit script supports differential scanning to track changes between audit runs, which is particularly useful for continuous monitoring and compliance:

```bash
# Run an initial scan
./gcp_audit.sh --project $PROJECT_ID --format json --export-evidence --level moderate

# Save the output directory for comparison
cp -r gcp_audit_results_* baseline_results

# Make a change to your environment (add a new IAM role, Storage bucket, etc.)

# Run a differential scan
./gcp_audit.sh --project $PROJECT_ID --format json --export-evidence --level moderate --diff baseline_results/
```

Check the differential report to verify it shows:

1. New configuration changes
2. Changes in compliance status
3. Added or removed resources

## Testing Common FedRAMP Control Scenarios

This section provides specific test scenarios for key FedRAMP control families.

### Access Control (AC) Tests

Test access control configurations:

```bash
# Create a test user
gcloud iam service-accounts create fedramp-test-user --display-name="FedRAMP Test User"

# Assign a role with least privilege (for testing AC-6)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:fedramp-test-user@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/viewer"

# Run the audit targeting AC controls
./gcp_audit.sh --project $PROJECT_ID --format html --export-evidence --level moderate
```

Check that the audit properly identifies:
- Account management (AC-2)
- Least privilege (AC-6)
- Remote access (AC-17)
- Session termination (AC-12)

### Audit and Accountability (AU) Tests

Test logging and auditing:

```bash
# Enable Data Access audit logs
gcloud logging settings update \
  --organization=$ORGANIZATION_ID \
  --enable-data-access

# Create a test log sink (for AU-3, AU-4)
gcloud logging sinks create test-audit-sink \
  storage.googleapis.com/$PROJECT_ID-logs \
  --project=$PROJECT_ID

# Run the audit targeting AU controls
./gcp_audit.sh --project $PROJECT_ID --format html --export-evidence --level moderate
```

Check that the audit properly identifies:
- Audit events (AU-2)
- Content of audit records (AU-3)
- Audit storage capacity (AU-4)
- Time stamps (AU-8)

### Incident Response (IR) Tests

Test incident response configurations:

```bash
# Enable Security Command Center
gcloud services enable securitycenter.googleapis.com --project=$PROJECT_ID

# Configure Security Command Center notifications
gcloud scc notifications create test-notification \
  --pubsub-topic projects/$PROJECT_ID/topics/scc-notifications \
  --project=$PROJECT_ID

# Run the audit targeting IR controls
./gcp_audit.sh --project $PROJECT_ID --format html --export-evidence --level moderate
```

Check that the audit properly identifies:
- Incident handling (IR-4)
- Incident monitoring (IR-5)
- Incident reporting (IR-6)

## Expected Results

When testing FedRAMP compliance, you should expect:

1. **Control Coverage**: All required controls for the specified impact level should be assessed
2. **Evidence Collection**: Technical artifacts should be properly collected and mapped to controls
3. **SSP Templates**: Implementation statements should be accurate and reflect actual configurations
4. **Container Security Integration**: NIST SP 800-190 controls should be mapped to FedRAMP requirements
5. **Severity Ratings**: FedRAMP-compliant severity ratings should be assigned to findings

## Troubleshooting

If you encounter issues with FedRAMP testing:

1. **Check Required APIs**:
   ```bash
   gcloud services list --project=$PROJECT_ID | grep -E 'security|logging|monitoring'
   ```

2. **Verify IAM Permissions**:
   ```bash
   gcloud projects get-iam-policy $PROJECT_ID
   ```

3. **Check Output Format**:
   If evidence files are missing, ensure you're using the `--export-evidence` flag

4. **Verify FedRAMP Level**:
   Make sure you're using a valid level (low, moderate, high)

## Cleanup

After testing, clean up the resources:

```bash
# Use Terraform to remove all infrastructure
cd /path/to/terraform
terraform destroy
```