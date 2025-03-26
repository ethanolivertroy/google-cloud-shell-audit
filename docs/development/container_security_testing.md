# NIST SP 800-190 Container Security Testing Guide

This document provides guidance on testing the NIST SP 800-190 container security compliance checks implemented in our audit script. The tests cover all major sections of the SP 800-190 Application Container Security Guide.

## Prerequisites

Before testing the container security checks, ensure you have:

1. Completed the environment setup described in `setup.md`
2. Deployed the test infrastructure using Terraform
3. Access to a Google Cloud project with GKE capabilities

## Setting Up Specific Test Scenarios

To thoroughly test the container security checks, you'll need to set up specific test scenarios. The following instructions create scenarios that will trigger various findings in the audit script.

### 1. Image Security Test Scenarios

#### 1.1. Container Analysis API

To test vulnerability scanning checks:

```bash
# Enable Container Analysis API
gcloud services enable containeranalysis.googleapis.com --project=$PROJECT_ID

# Build and push a test container to Container Registry
cd /tmp
mkdir -p container-test
cd container-test

# Create a simple Dockerfile
cat > Dockerfile << EOF
FROM debian:11
RUN apt-get update && apt-get install -y curl
ENTRYPOINT ["curl"]
EOF

# Build and push
gcloud builds submit --tag gcr.io/$PROJECT_ID/test-image:v1
```

#### 1.2. Binary Authorization

Enable Binary Authorization with an enforcing policy:

```bash
# Enable Binary Authorization
gcloud services enable binaryauthorization.googleapis.com --project=$PROJECT_ID

# Configure a simple policy
cat > policy.yaml << EOF
globalPolicyEvaluationMode: ENABLE
defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  requireAttestationsBy:
  - projects/$PROJECT_ID/attestors/test-attestor
EOF

# Create an attestor and deploy the policy
gcloud container binauthz attestors create test-attestor \
  --project=$PROJECT_ID \
  --attestation-authority-note=test-note \
  --attestation-authority-note-project=$PROJECT_ID

gcloud container binauthz policy import policy.yaml --project=$PROJECT_ID
```

### 2. Container Runtime Security Test Scenarios

#### 2.1. Runtime Resource Limitations

Set up resource quotas in the GKE cluster:

```bash
# Get credentials for the GKE cluster
gcloud container clusters get-credentials audit-test-gke-cluster --zone=us-central1-a --project=$PROJECT_ID

# Create a namespace for testing
kubectl create namespace test-ns

# Create resource quota
cat > quota.yaml << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: test-quota
spec:
  hard:
    cpu: "4"
    memory: 4Gi
    pods: "10"
EOF

kubectl apply -f quota.yaml -n test-ns
```

#### 2.2. Pod Security Standards

Set up Pod Security Standards to test privilege controls:

```bash
# Label the namespace with Pod Security Standards
kubectl label namespace test-ns pod-security.kubernetes.io/enforce=restricted

# Create a seccomp profile for testing
cat > seccomp-profile.yaml << EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: test-seccomp
handler: runc
overhead:
  podFixed:
    memory: "50Mi"
    cpu: "100m"
EOF

kubectl apply -f seccomp-profile.yaml
```

### 3. Orchestrator Security Test Scenarios

#### 3.1. mTLS Configuration

Set up a service mesh with mTLS:

```bash
# Install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with demo profile
istioctl install --set profile=demo -y

# Create test namespace with Istio injection
kubectl create namespace istio-test
kubectl label namespace istio-test istio-injection=enabled

# Enable strict mTLS
cat > mtls-policy.yaml << EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF

kubectl apply -f mtls-policy.yaml
```

#### 3.2. Admission Controllers

Set up admission controllers:

```bash
# Set up OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.9/deploy/gatekeeper.yaml

# Create a constraint template
cat > template.yaml << EOF
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("missing required labels: %v", [missing])
        }
EOF

kubectl apply -f template.yaml

# Create a constraint
cat > constraint.yaml << EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-label
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    labels: ["app"]
EOF

kubectl apply -f constraint.yaml
```

### 4. Container Logging and Monitoring Test Scenarios

Set up logging and monitoring:

```bash
# Deploy a Prometheus stack for monitoring
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring

# Deploy Fluent Bit for logging
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  --set config.outputs="\
[OUTPUT] \n \
    Name                   gcs \n \
    Match                  kube.* \n \
    Bucket                 $PROJECT_ID-logs \n \
    Credential_File        /var/secrets/google/key.json \n"
```

### 5. Container Secrets Management Test Scenarios

Set up Kubernetes secrets and Secret Manager integration:

```bash
# Install External Secrets Operator
kubectl apply -f https://github.com/external-secrets/external-secrets/releases/download/v0.7.0/external-secrets.yaml

# Create a Secret in Secret Manager
gcloud secrets create test-k8s-secret --data-file=- --project=$PROJECT_ID << EOF
supersecretvalue
EOF

# Allow the GKE service account to access Secret Manager
SERVICE_ACCOUNT=$(kubectl get serviceaccount default -o jsonpath='{.metadata.name}')
gcloud secrets add-iam-policy-binding test-k8s-secret \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/$SERVICE_ACCOUNT]" \
  --role="roles/secretmanager.secretAccessor" \
  --project=$PROJECT_ID

# Configure External Secrets
cat > secretstore.yaml << EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcp-secret-store
spec:
  provider:
    gcpsm:
      projectID: $PROJECT_ID
      auth:
        workloadIdentity:
          clusterLocation: us-central1-a
          clusterName: audit-test-gke-cluster
          serviceAccountRef:
            name: $SERVICE_ACCOUNT
EOF

kubectl apply -f secretstore.yaml

# Create External Secret
cat > externalsecret.yaml << EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: external-test-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secret-store
    kind: SecretStore
  target:
    name: k8s-test-secret
  data:
  - secretKey: secret-value
    remoteRef:
      key: test-k8s-secret
EOF

kubectl apply -f externalsecret.yaml
```

### 6. Container Incident Response Test Scenarios

Set up incident response tools:

```bash
# Install Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco \
  --namespace monitoring \
  --set ebpf.enabled=true
```

## Running the Audit on Test Scenarios

After setting up the test scenarios, run the audit script to check the container security compliance:

```bash
# Run the script with the container security focused parameters
cd /path/to/google-cloud-shell-audit
./gcp_audit.sh --project $PROJECT_ID --format html --verbose --export-evidence --level high
```

## Verifying Results

After running the audit, verify the results for each section of NIST SP 800-190:

1. **Image Security**:
   - Check if Container Analysis is properly detected
   - Verify Binary Authorization enforcement is reported correctly

2. **Container Runtime Security**:
   - Confirm resource quotas are detected
   - Verify Pod Security Standards are properly reported

3. **Orchestrator Security**:
   - Verify mTLS configuration is detected
   - Check that admission controllers are properly reported

4. **Container Logging and Monitoring**:
   - Confirm Prometheus for monitoring is detected
   - Verify Fluent Bit for logging is reported

5. **Container Secrets Management**:
   - Check External Secrets integration detection
   - Verify Secret Manager integration is properly reported

6. **Container Incident Response**:
   - Verify Falco detection for runtime security monitoring

## Expected Results

The following results should be observed when running the audit on the test environment:

| Section | Test | Expected Result |
|---------|------|-----------------|
| Image Security | Container Analysis | PASS |
| Image Security | Binary Authorization | PASS |
| Container Runtime | Resource Quotas | PASS |
| Container Runtime | Pod Security | PASS |
| Orchestrator Security | mTLS | PASS |
| Orchestrator Security | Admission Controllers | PASS |
| Logging & Monitoring | Prometheus | PASS |
| Logging & Monitoring | Fluent Bit | PASS |
| Secrets Management | External Secrets | PASS |
| Incident Response | Falco | PASS |

## Troubleshooting

If any tests fail, check the following:

1. **API Enablement**:
   ```bash
   gcloud services list --project=$PROJECT_ID | grep -E 'container|binary|security'
   ```

2. **GKE Configuration**:
   ```bash
   gcloud container clusters describe audit-test-gke-cluster --zone=us-central1-a --project=$PROJECT_ID
   ```

3. **Kubernetes Resources**:
   ```bash
   kubectl get all --all-namespaces
   ```

4. **Service Accounts and Permissions**:
   ```bash
   gcloud iam service-accounts list --project=$PROJECT_ID
   ```

## Cleanup

After testing, clean up the resources:

```bash
# Remove test scenarios
kubectl delete namespace istio-test
kubectl delete namespace test-ns
kubectl delete namespace monitoring

# Use Terraform to remove all infrastructure
cd /path/to/terraform
terraform destroy
```