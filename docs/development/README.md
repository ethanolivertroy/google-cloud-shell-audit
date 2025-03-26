# GCP Audit Development Documentation

This directory contains documentation and resources for developers working on the Google Cloud Shell Audit tool, which provides comprehensive NIST SP 800-53 Rev5 & FedRAMP compliance assessments for Google Cloud Platform environments.

## Documentation Index

### Setup and Infrastructure
- [Development Environment Setup](setup.md) - Instructions for setting up the development environment and test infrastructure

### Testing
- [Container Security Testing](container_security_testing.md) - Guide for testing NIST SP 800-190 container security compliance checks
- [FedRAMP Testing](fedramp_testing.md) - Guide for testing FedRAMP compliance assessment and evidence collection

## Development Infrastructure

The `/terraform` directory at the repository root contains Infrastructure as Code (IaC) to deploy a test environment in Google Cloud Platform. This environment includes:

- GKE clusters with security features enabled
- Compute Engine instances 
- Cloud Storage buckets
- IAM configurations
- Logging and monitoring setup
- Secret Manager resources
- Network configuration

## Development Workflow

1. **Clone the repository**
2. **Set up the development environment** following the instructions in `setup.md`
3. **Deploy test infrastructure** using Terraform
4. **Make changes to the script**
5. **Test your changes** against the test infrastructure
6. **Submit a pull request** with your changes

## Testing Requirements

When making changes to the script, ensure:

1. All NIST SP 800-53 Rev5 control families are properly covered
2. FedRAMP compliance mappings are accurate
3. Evidence collection functions properly for auditors
4. Container security checks align with NIST SP 800-190 guidance
5. Output formats (JSON, CSV, HTML, SSP) function correctly

## Contributing Guidelines

When contributing to this project:

1. **Follow bash best practices** for script development
2. **Maintain backward compatibility** when possible
3. **Document all changes** thoroughly
4. **Test against various GCP environments** to ensure compatibility
5. **Include mappings** to relevant NIST controls

## Additional Resources

- [NIST SP 800-53 Rev5 Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [NIST SP 800-190 Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)
- [FedRAMP Documentation](https://www.fedramp.gov/documents/)
- [Google Cloud Security Best Practices](https://cloud.google.com/security/best-practices)