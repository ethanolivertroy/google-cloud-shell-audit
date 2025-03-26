# Function to generate enhanced compliance report
generate_compliance_report() {
  local project="$1"
  local output_file="$OUTPUT_DIR/${REPORT_PREFIX}_compliance_$project.$REPORT_FORMAT"
  
  echo -e "${BLUE}Generating compliance report for project: $project${NC}"
  
  # Use parallel processing if enabled
  if [ "$PARALLEL_JOBS" -gt 1 ]; then
    echo -e "${CYAN}Running compliance checks in parallel mode with $PARALLEL_JOBS jobs...${NC}"
  fi
  
  # Run all check categories, displaying progress
  echo -e "${CYAN}Running IAM checks...${NC}"
  local iam_checks=$(check_iam "$project")
  
  echo -e "${CYAN}Running advanced IAM checks...${NC}"
  local iam_advanced_checks=$(check_iam_advanced "$project")
  
  echo -e "${CYAN}Running logging and monitoring checks...${NC}"
  local logging_checks=$(check_logging "$project")
  
  echo -e "${CYAN}Running storage checks...${NC}"
  local storage_checks=$(check_storage "$project")
  
  echo -e "${CYAN}Running networking checks...${NC}"
  local network_checks=$(check_networking "$project")
  
  echo -e "${CYAN}Running advanced networking checks...${NC}"
  local network_advanced_checks=$(check_networking_advanced "$project")
  
  echo -e "${CYAN}Running VPC Service Controls checks...${NC}"
  local vpc_sc_checks=$(check_vpc_service_controls "$project")
  
  echo -e "${CYAN}Running compute checks...${NC}"
  local compute_checks=$(check_compute "$project")
  
  echo -e "${CYAN}Running confidential computing checks...${NC}"
  local confidential_checks=$(check_confidential_computing "$project")
  
  echo -e "${CYAN}Running GKE checks...${NC}"
  local gke_checks=$(check_gke "$project")
  
  echo -e "${CYAN}Running Cloud SQL checks...${NC}"
  local sql_checks=$(check_sql "$project")
  
  echo -e "${CYAN}Running serverless checks...${NC}"
  local serverless_checks=$(check_serverless "$project")
  
  echo -e "${CYAN}Running secrets and KMS checks...${NC}"
  local secrets_checks=$(check_secrets "$project")
  
  echo -e "${CYAN}Running Security Command Center checks...${NC}"
  local security_center_checks=$(check_security_center "$project")
  
  echo -e "${CYAN}Running Asset Inventory checks...${NC}"
  local asset_inventory_checks=$(check_asset_inventory "$project")
  
  echo -e "${CYAN}Running Data Loss Prevention checks...${NC}"
  local dlp_checks=$(check_dlp "$project")
  
  echo -e "${CYAN}Running Identity-Aware Proxy checks...${NC}"
  local iap_checks=$(check_iap "$project")
  
  echo -e "${CYAN}Running Organization Policy checks...${NC}"
  local org_policy_checks=$(check_org_policies "$project")
  
  echo -e "${CYAN}Running Binary Authorization checks...${NC}"
  local binary_auth_checks=$(check_binary_authorization "$project")
  
  echo -e "${CYAN}Running Supply Chain Security checks...${NC}"
  local supply_chain_checks=$(check_supply_chain "$project")
  
  echo -e "${CYAN}Running NIST SP 800-190 Container Security checks...${NC}"
  local container_800_190_checks=$(check_container_800_190 "$project")
  
  echo -e "${CYAN}Running Backup and Recovery checks...${NC}"
  local backup_recovery_checks=$(check_backup_recovery "$project")
  
  # Add custom controls if provided
  local custom_checks="[]"
  if [ -n "$CUSTOM_CONTROLS" ] && [ -f "$CUSTOM_CONTROLS" ]; then
    echo -e "${CYAN}Running custom controls from $CUSTOM_CONTROLS...${NC}"
    custom_checks=$(jq -r '.controls | map(
      run_check(.id, .description, .command, .success_pattern, .fail_pattern, .remediation, .severity)
    )' "$CUSTOM_CONTROLS")
  fi
  
  # Combine all checks
  local all_checks="
  {
    \"project\": \"$project\",
    \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"fedramp_level\": \"$FEDRAMP_LEVEL\",
    \"summary\": {
      \"total\": 0,
      \"pass\": 0,
      \"fail\": 0,
      \"warn\": 0,
      \"error\": 0,
      \"skipped\": 0
    },
    \"categories\": {
      \"iam\": $iam_checks,
      \"iam_advanced\": $iam_advanced_checks,
      \"logging\": $logging_checks,
      \"storage\": $storage_checks,
      \"networking\": $network_checks,
      \"networking_advanced\": $network_advanced_checks,
      \"vpc_service_controls\": $vpc_sc_checks,
      \"compute\": $compute_checks,
      \"confidential_computing\": $confidential_checks,
      \"gke\": $gke_checks,
      \"sql\": $sql_checks,
      \"serverless\": $serverless_checks,
      \"secrets\": $secrets_checks,
      \"security_center\": $security_center_checks,
      \"asset_inventory\": $asset_inventory_checks,
      \"dlp\": $dlp_checks,
      \"iap\": $iap_checks,
      \"org_policies\": $org_policy_checks,
      \"binary_auth\": $binary_auth_checks,
      \"supply_chain\": $supply_chain_checks,
      \"container_800_190\": $container_800_190_checks,
      \"backup_recovery\": $backup_recovery_checks,
      \"custom\": $custom_checks
    }
  }"
  
  # Calculate summary statistics
  local total=$(echo "$all_checks" | jq '.categories | to_entries | map(.value) | flatten | length')
  local pass=$(echo "$all_checks" | jq '.categories | to_entries | map(.value) | flatten | map(select(.status == "PASS")) | length')
  local fail=$(echo "$all_checks" | jq '.categories | to_entries | map(.value) | flatten | map(select(.status == "FAIL")) | length')
  local warn=$(echo "$all_checks" | jq '.categories | to_entries | map(.value) | flatten | map(select(.status == "WARN")) | length')
  local error=$(echo "$all_checks" | jq '.categories | to_entries | map(.value) | flatten | map(select(.status == "ERROR")) | length')
  local skipped=$(echo "$all_checks" | jq '.categories | to_entries | map(.value) | flatten | map(select(.status == "SKIPPED" or .status == "INFO")) | length')
  
  # Update summary
  all_checks=$(echo "$all_checks" | jq ".summary.total = $total | .summary.pass = $pass | .summary.fail = $fail | .summary.warn = $warn | .summary.error = $error | .summary.skipped = $skipped")
  
  # Format and save the report
  case "$REPORT_FORMAT" in
    json)
      echo "$all_checks" | jq . > "$output_file"
      ;;
    csv)
      # Header
      echo "Category,Check ID,Description,Controls,Status,Severity,Result,Remediation" > "$output_file"
      # Generate CSV rows
      echo "$all_checks" | jq -r '.categories | to_entries[] | .key as $category | .value[] | [$category, .id, .description, .controls, .status, (.severity // "Medium"), .result, .remediation] | @csv' >> "$output_file"
      ;;
    html)
      # Create HTML report
      cat > "$output_file" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>GCP FedRAMP Compliance Report - $project</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
    h1, h2, h3 { color: #4285f4; }
    .summary { display: flex; margin-bottom: 20px; flex-wrap: wrap; }
    .summary-item { margin-right: 20px; margin-bottom: 10px; padding: 10px; border-radius: 5px; min-width: 100px; text-align: center; }
    .pass { background-color: #0f9d58; color: white; }
    .fail { background-color: #db4437; color: white; }
    .warn { background-color: #f4b400; color: white; }
    .error { background-color: #9e9e9e; color: white; }
    .skipped { background-color: #4285f4; color: white; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    th { background-color: #4285f4; color: white; padding: 8px; text-align: left; }
    td { border: 1px solid #ddd; padding: 8px; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    .control-tag { display: inline-block; background-color: #e0e0e0; padding: 2px 5px; margin: 2px; border-radius: 3px; }
    .category-section { margin-bottom: 30px; }
    .severity-high { border-left: 5px solid #db4437; }
    .severity-medium { border-left: 5px solid #f4b400; }
    .severity-low { border-left: 5px solid #0f9d58; }
    .filter-controls { margin-bottom: 20px; display: flex; flex-wrap: wrap; gap: 10px; }
    .filter-controls button { padding: 8px 12px; border: none; border-radius: 4px; cursor: pointer; background-color: #f1f1f1; }
    .filter-controls button.active { background-color: #4285f4; color: white; }
    .filter-controls button:hover { background-color: #e1e1e1; }
    .search-box { margin-bottom: 20px; }
    .search-box input { padding: 8px; width: 300px; }
    #compliance-summary { width: 600px; height: 300px; margin: 20px 0; }
    .fedramp-info { margin: 20px 0; padding: 15px; background-color: #f8f9fa; border-radius: 5px; }
  </style>
  <script>
    function filterResults(status) {
      const rows = document.querySelectorAll('table tbody tr');
      rows.forEach(row => {
        if (status === 'all' || row.querySelector('td:nth-child(4)').textContent === status) {
          row.style.display = '';
        } else {
          row.style.display = 'none';
        }
      });
      
      // Update active button
      document.querySelectorAll('.filter-controls button').forEach(btn => {
        btn.classList.remove('active');
      });
      document.querySelector(\`button[data-status="\${status}"]\`).classList.add('active');
    }
    
    function searchChecks() {
      const searchTerm = document.getElementById('search-input').value.toLowerCase();
      const rows = document.querySelectorAll('table tbody tr');
      
      rows.forEach(row => {
        const text = row.textContent.toLowerCase();
        if (searchTerm === '' || text.includes(searchTerm)) {
          row.style.display = '';
        } else {
          row.style.display = 'none';
        }
      });
    }
    
    document.addEventListener('DOMContentLoaded', function() {
      // Initialize the filter buttons
      document.querySelectorAll('.filter-controls button').forEach(btn => {
        btn.addEventListener('click', function() {
          filterResults(this.getAttribute('data-status'));
        });
      });
      
      // Initialize search
      document.getElementById('search-input').addEventListener('keyup', searchChecks);
    });
  </script>
</head>
<body>
  <h1>GCP FedRAMP Compliance Report</h1>
  <p><strong>Project:</strong> $project</p>
  <p><strong>FedRAMP Level:</strong> $(echo $FEDRAMP_LEVEL | tr '[:lower:]' '[:upper:]')</p>
  <p><strong>Generated:</strong> $(date -u +"%Y-%m-%d %H:%M:%S UTC")</p>
  
  <div class="fedramp-info">
    <h3>FedRAMP $(echo $FEDRAMP_LEVEL | tr '[:lower:]' '[:upper:]') Compliance Overview</h3>
    <p>This report evaluates Google Cloud Platform resources against NIST SP 800-53 Rev5 controls 
    required for FedRAMP $(echo $FEDRAMP_LEVEL | tr '[:lower:]' '[:upper:]') compliance. It examines configuration settings,
    security controls, and best practices across multiple GCP services.</p>
  </div>
  
  <h2>Summary</h2>
  <div class="summary">
    <div class="summary-item pass">Pass: $pass</div>
    <div class="summary-item fail">Fail: $fail</div>
    <div class="summary-item warn">Warning: $warn</div>
    <div class="summary-item error">Error: $error</div>
    <div class="summary-item skipped">Skipped: $skipped</div>
    <div class="summary-item">Total: $total</div>
  </div>
  
  <div class="filter-controls">
    <h3>Filter Results:</h3>
    <button data-status="all" class="active">All</button>
    <button data-status="PASS">Pass</button>
    <button data-status="FAIL">Fail</button>
    <button data-status="WARN">Warning</button>
    <button data-status="ERROR">Error</button>
    <button data-status="SKIPPED">Skipped</button>
  </div>
  
  <div class="search-box">
    <h3>Search Checks:</h3>
    <input type="text" id="search-input" placeholder="Search by keyword, control, or description...">
  </div>
EOF

      # Add each category
      echo "$all_checks" | jq -r '.categories | to_entries[] | select(.value | length > 0) | .key' | while read -r category; do
        cat >> "$output_file" << EOF
  <div class="category-section">
    <h2>$(echo "$category" | tr '_' ' ' | tr '[:lower:]' '[:upper:]')</h2>
    <table>
      <thead>
        <tr>
          <th>Check ID</th>
          <th>Description</th>
          <th>Controls</th>
          <th>Status</th>
          <th>Severity</th>
          <th>Remediation</th>
        </tr>
      </thead>
      <tbody>
EOF

        # Add rows for this category
        echo "$all_checks" | jq -r --arg category "$category" '.categories[$category][] | [.id, .description, .controls, .status, (.severity // "Medium"), .remediation] | @tsv' | while IFS=$'\t' read -r id description controls status severity remediation; do
          # Format controls as tags
          control_tags=""
          IFS=',' read -r -a control_array <<< "$controls"
          for control in "${control_array[@]}"; do
            control_tags+="<span class=\"control-tag\">$control</span> "
          done
          
          # Add row with status color and severity indicator
          status_class=$(echo "$status" | tr '[:upper:]' '[:lower:]')
          severity_class="severity-$(echo "$severity" | tr '[:upper:]' '[:lower:]')"
          cat >> "$output_file" << EOF
      <tr class="$severity_class">
        <td>$id</td>
        <td>$description</td>
        <td>$control_tags</td>
        <td class="$status_class">$status</td>
        <td>$severity</td>
        <td>$remediation</td>
      </tr>
EOF
        done
        
        # Close the table
        cat >> "$output_file" << EOF
      </tbody>
    </table>
  </div>
EOF
      done
      
      # Close the HTML
      cat >> "$output_file" << EOF
</body>
</html>
EOF
      ;;
    scc)
      # Generate Security Command Center findings format
      local scc_dir="$OUTPUT_DIR/scc"
      mkdir -p "$scc_dir"
      local scc_file="$scc_dir/${REPORT_PREFIX}_scc_findings_$project.json"
      
      # Convert each failed check to an SCC finding
      echo "$all_checks" | jq -r '.categories | to_entries[] | .value[] | select(.status == "FAIL")' | \
      while read -r check; do
        convert_to_scc_finding "$check" "$project" >> "$scc_file"
        echo "," >> "$scc_file"
      done
      
      # Clean up the file (remove trailing comma and add brackets)
      sed -i '$ s/,$//' "$scc_file"
      sed -i '1 i [' "$scc_file"
      echo "]" >> "$scc_file"
      
      echo -e "${GREEN}Security Command Center findings saved to: $scc_file${NC}"
      ;;
    ssp)
      # Generate System Security Plan format
      # This will create a structured SSP-compatible JSON with control mappings
      generate_ssp_template "$project"
      ;;
    *)
      echo -e "${RED}ERROR: Unsupported report format: $REPORT_FORMAT${NC}"
      exit 1
      ;;
  esac
  
  echo -e "${GREEN}Compliance report saved to: $output_file${NC}"
  
  # Generate differential report if a previous scan was specified
  if [ -n "$PREVIOUS_SCAN" ]; then
    local prev_file="$PREVIOUS_SCAN/${REPORT_PREFIX}_compliance_$project.json"
    local diff_file="$OUTPUT_DIR/${REPORT_PREFIX}_diff_$project.json"
    
    if [ -f "$prev_file" ]; then
      generate_diff_report "$output_file" "$prev_file" "$diff_file"
    else
      echo -e "${YELLOW}WARNING: Previous compliance report not found: $prev_file${NC}"
    fi
  fi
  
  # Generate evidence collection if requested
  if [ "$EXPORT_EVIDENCE" == "true" ]; then
    generate_evidence_collection "$project"
  fi
}

# Function to check NIST SP 800-190 Container Security compliance
check_container_800_190() {
  local project="$1"
  echo -e "${CYAN}Running NIST SP 800-190 Container Security checks...${NC}"
  
  local checks=()
  local result=""
  local status=""
  
  # ================ 1. IMAGE SECURITY SECTION ================
  
  # 1.1 Image vulnerability scanning
  result=$(gcloud container images list --repository=gcr.io/$project 2>/dev/null | grep -v "NAME" || echo "")
  if [[ -n "$result" ]]; then
    # Check if Artifact Analysis (Container Analysis) API is enabled
    local api_enabled=$(gcloud services list --project="$project" --filter="config.name=containeranalysis.googleapis.com" --format="value(config.name)" 2>/dev/null)
    if [[ -n "$api_enabled" ]]; then
      status="PASS"
      result="Container Analysis API is enabled for vulnerability scanning."
    else
      status="FAIL"
      result="Container Analysis API is not enabled for vulnerability scanning."
    fi
  else
    status="INFO"
    result="No container images found for vulnerability scanning check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-1.1",
    "description": "Container images are automatically scanned for vulnerabilities",
    "controls": "NIST-800-190-4.1.1,SI-10,SI-7",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Enable Container Analysis API and configure automatic vulnerability scanning for container images."
  }
EOF
  ))
  
  # 1.2 Image configuration security
  # Check if Binary Authorization is enabled 
  local binauth_enabled=$(gcloud services list --project="$project" --filter="config.name=binaryauthorization.googleapis.com" --format="value(config.name)" 2>/dev/null)
  if [[ -n "$binauth_enabled" ]]; then
    local binauth_policy=$(gcloud container binauthz policy export --project="$project" 2>/dev/null)
    if [[ -n "$binauth_policy" ]] && [[ "$binauth_policy" != *"defaultAdmissionRule"*"evaluationMode: ALWAYS_ALLOW"* ]]; then
      status="PASS"
      result="Binary Authorization is enabled with enforcing policy."
    else
      status="WARN"
      result="Binary Authorization is enabled but may not be enforcing signature verification."
    fi
  else
    status="FAIL"
    result="Binary Authorization is not enabled to enforce container image signing and verification."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-1.2",
    "description": "Container image signature verification is enforced",
    "controls": "NIST-800-190-4.1.2,CM-4,CM-14,SR-4",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Enable Binary Authorization and configure enforcement policies for container deployments."
  }
EOF
  ))
  
  # 1.3 Base image sourcing
  # Check if Artifact Registry is used for base images
  local artifact_registry=$(gcloud services list --project="$project" --filter="config.name=artifactregistry.googleapis.com" --format="value(config.name)" 2>/dev/null)
  if [[ -n "$artifact_registry" ]]; then
    local private_repos=$(gcloud artifacts repositories list --project="$project" --format="value(name)" 2>/dev/null)
    if [[ -n "$private_repos" ]]; then
      status="PASS"
      result="Artifact Registry is used for managing container images."
    else
      status="WARN"
      result="Artifact Registry is enabled but no repositories configured."
    fi
  else
    status="FAIL"
    result="Artifact Registry is not enabled for secure base image management."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-1.3",
    "description": "Base images are sourced from trusted, private registries",
    "controls": "NIST-800-190-4.1.3,CM-2,SA-10,SR-3",
    "severity": "Medium",
    "status": "$status",
    "result": "$result",
    "remediation": "Configure Artifact Registry with private repositories for storing approved base images."
  }
EOF
  ))
  
  # ================ 2. CONTAINER RUNTIME SECURITY ================
  
  # 2.1 Runtime vulnerability monitoring
  # Check if Security Command Center is configured for container runtime monitoring
  local scc_enabled=$(gcloud services list --project="$project" --filter="config.name=securitycenter.googleapis.com" --format="value(config.name)" 2>/dev/null)
  if [[ -n "$scc_enabled" ]]; then
    status="PASS"
    result="Security Command Center is enabled for runtime vulnerability monitoring."
  else
    status="FAIL"
    result="Security Command Center is not enabled for runtime container vulnerability monitoring."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-2.1",
    "description": "Container runtime vulnerability monitoring is implemented",
    "controls": "NIST-800-190-4.2.1,SI-4,SI-10,RA-5",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Enable Security Command Center and configure container runtime monitoring."
  }
EOF
  ))
  
  # 2.2 Runtime resource limitations
  # Check GKE clusters for resource quotas
  local clusters=$(gcloud container clusters list --project="$project" --format="value(name)" 2>/dev/null)
  if [[ -n "$clusters" ]]; then
    local resource_quotas=""
    for cluster in $clusters; do
      local zone=$(gcloud container clusters list --project="$project" --filter="name=$cluster" --format="value(zone)" 2>/dev/null)
      if [[ -n "$zone" ]]; then
        # Get credentials and check for resource quotas
        gcloud container clusters get-credentials "$cluster" --zone="$zone" --project="$project" > /dev/null 2>&1
        local namespace_quotas=$(kubectl get resourcequota --all-namespaces 2>/dev/null | grep -v "No resources found")
        if [[ -n "$namespace_quotas" ]]; then
          resource_quotas="yes"
          break
        fi
      fi
    done
    
    if [[ "$resource_quotas" == "yes" ]]; then
      status="PASS"
      result="Resource quotas are implemented for container runtimes."
    else
      status="FAIL"
      result="Resource quotas are not implemented for container runtimes."
    fi
  else
    status="INFO"
    result="No GKE clusters found for resource quota check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-2.2",
    "description": "Container runtime resource limitations are enforced",
    "controls": "NIST-800-190-4.2.2,SC-6,CM-2",
    "severity": "Medium",
    "status": "$status",
    "result": "$result",
    "remediation": "Implement resource quotas and limits for all Kubernetes namespaces."
  }
EOF
  ))
  
  # 2.3 Container runtime privileges and security profiles
  # Check GKE clusters for Pod Security Standards and restricted profiles
  if [[ -n "$clusters" ]]; then
    local pss_enabled=false
    local seccomp_default=false
    local podsecurity_admission=false
    
    for cluster in $clusters; do
      local zone=$(gcloud container clusters list --project="$project" --filter="name=$cluster" --format="value(zone)" 2>/dev/null)
      if [[ -n "$zone" ]]; then
        # Get credentials for the cluster
        gcloud container clusters get-credentials "$cluster" --zone="$zone" --project="$project" > /dev/null 2>&1
        
        # Check for Pod Security Standards or PSPs
        local psp_exists=$(kubectl get podsecuritypolicies 2>/dev/null)
        local pss_policies=$(kubectl get ns -o yaml 2>/dev/null | grep "pod-security.kubernetes.io/enforce: restricted")
        
        if [[ -n "$psp_exists" || -n "$pss_policies" ]]; then
          pss_enabled=true
        fi
        
        # Check for seccomp profiles
        local seccomp_profiles=$(kubectl get nodes -o yaml 2>/dev/null | grep "seccompDefault: true")
        if [[ -n "$seccomp_profiles" ]]; then
          seccomp_default=true
        fi
        
        # Check for PodSecurity admission controller
        local pod_security_admission=$(kubectl get ns -o yaml 2>/dev/null | grep "pod-security.kubernetes.io")
        if [[ -n "$pod_security_admission" ]]; then
          podsecurity_admission=true
        fi
      fi
    done
    
    if [[ "$pss_enabled" == true && ("$seccomp_default" == true || "$podsecurity_admission" == true) ]]; then
      status="PASS"
      result="Container runtime security is enforced with Pod Security Standards/Policies and security profiles."
    elif [[ "$pss_enabled" == true ]]; then
      status="WARN"
      result="Basic Pod Security Standards/Policies are implemented, but additional security profiles may be missing."
    else
      status="FAIL"
      result="Container runtime security lacks Pod Security Standards/Policies and security profiles."
    fi
  else
    status="INFO"
    result="No GKE clusters found for container runtime security check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-2.3",
    "description": "Container runtime privileges are restricted with security profiles",
    "controls": "NIST-800-190-4.2.3,AC-6,CM-7,SI-7",
    "severity": "High",
    "status": "$status",
    "result": "$result", 
    "remediation": "Implement Pod Security Standards in 'restricted' mode and enable seccomp profiles."
  }
EOF
  ))
  
  # ================ 3. ORCHESTRATOR SECURITY ================
  
  # 3.1 Orchestrator authentication and authorization
  # Check GKE clusters for RBAC and Workload Identity
  if [[ -n "$clusters" ]]; then
    local rbac_enabled=false
    local workload_identity=false
    
    for cluster in $clusters; do
      local zone=$(gcloud container clusters list --project="$project" --filter="name=$cluster" --format="value(zone)" 2>/dev/null)
      if [[ -n "$zone" ]]; then
        # Check RBAC
        local cluster_rbac=$(gcloud container clusters describe "$cluster" --zone="$zone" --project="$project" --format="value(legacyAbac.enabled)" 2>/dev/null)
        # Inverted logic - legacyAbac=false means RBAC is enabled
        if [[ "$cluster_rbac" == "false" || -z "$cluster_rbac" ]]; then
          rbac_enabled=true
        fi
        
        # Check Workload Identity
        local cluster_wi=$(gcloud container clusters describe "$cluster" --zone="$zone" --project="$project" --format="value(workloadIdentityConfig.workloadPool)" 2>/dev/null)
        if [[ -n "$cluster_wi" ]]; then
          workload_identity=true
        fi
      fi
    done
    
    if [[ "$rbac_enabled" == true && "$workload_identity" == true ]]; then
      status="PASS"
      result="RBAC is enabled and Workload Identity is configured for GKE clusters."
    elif [[ "$rbac_enabled" == true ]]; then
      status="WARN"
      result="RBAC is enabled but Workload Identity is not configured for all GKE clusters."
    else
      status="FAIL"
      result="RBAC and/or Workload Identity are not properly configured on GKE clusters."
    fi
  else
    status="INFO"
    result="No GKE clusters found for orchestrator security check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-3.1",
    "description": "Orchestrator authentication and authorization are securely configured",
    "controls": "NIST-800-190-4.3.1,AC-2,AC-3,AC-6,IA-2",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Enable RBAC and configure Workload Identity for all GKE clusters."
  }
EOF
  ))
  
  # 3.2 Orchestrator cluster segmentation
  # Check GKE clusters for network policy and private clusters
  if [[ -n "$clusters" ]]; then
    local network_policy=false
    local private_cluster=false
    
    for cluster in $clusters; do
      local zone=$(gcloud container clusters list --project="$project" --filter="name=$cluster" --format="value(zone)" 2>/dev/null)
      if [[ -n "$zone" ]]; then
        # Check Network Policy
        local cluster_np=$(gcloud container clusters describe "$cluster" --zone="$zone" --project="$project" --format="value(networkPolicy.enabled)" 2>/dev/null)
        if [[ "$cluster_np" == "true" ]]; then
          network_policy=true
        fi
        
        # Check Private Cluster
        local cluster_private=$(gcloud container clusters describe "$cluster" --zone="$zone" --project="$project" --format="value(privateClusterConfig.enablePrivateNodes)" 2>/dev/null)
        if [[ "$cluster_private" == "true" ]]; then
          private_cluster=true
        fi
      fi
    done
    
    if [[ "$network_policy" == true && "$private_cluster" == true ]]; then
      status="PASS"
      result="GKE clusters have network policies and private node configuration enabled."
    elif [[ "$network_policy" == true || "$private_cluster" == true ]]; then
      status="WARN"
      result="GKE clusters have partial segmentation controls implemented."
    else
      status="FAIL"
      result="GKE clusters lack proper segmentation (neither network policies nor private clusters)."
    fi
  else
    status="INFO"
    result="No GKE clusters found for orchestrator segmentation check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-3.2",
    "description": "Container orchestrator has proper cluster segmentation",
    "controls": "NIST-800-190-4.3.2,SC-7,AC-4,SC-3",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Enable network policies and configure private GKE clusters."
  }
EOF
  ))
  
  # 3.3 Service mesh and mTLS
  # Check if Anthos Service Mesh or Istio is configured for mTLS
  if [[ -n "$clusters" ]]; then
    local mtls_enabled=false
    local service_mesh_exists=false
    
    for cluster in $clusters; do
      local zone=$(gcloud container clusters list --project="$project" --filter="name=$cluster" --format="value(zone)" 2>/dev/null)
      if [[ -n "$zone" ]]; then
        # Get credentials for the cluster
        gcloud container clusters get-credentials "$cluster" --zone="$zone" --project="$project" > /dev/null 2>&1
        
        # Check for Anthos Service Mesh or Istio
        local asm_namespace=$(kubectl get namespace asm-system 2>/dev/null)
        local istio_namespace=$(kubectl get namespace istio-system 2>/dev/null)
        
        if [[ -n "$asm_namespace" || -n "$istio_namespace" ]]; then
          service_mesh_exists=true
          
          # Check for PeerAuthentication with mTLS
          local mesh_namespace="istio-system"
          if [[ -n "$asm_namespace" ]]; then
            mesh_namespace="asm-system"
          fi
          
          # Check for strict mTLS policy
          local peer_auth=$(kubectl get peerauthentication -n "$mesh_namespace" -o jsonpath="{.items[*].spec.mtls.mode}" 2>/dev/null | grep "STRICT")
          if [[ -n "$peer_auth" ]]; then
            mtls_enabled=true
            break
          fi
          
          # Alternative check for mesh-wide mTLS
          local mesh_config=$(kubectl get configmap -n "$mesh_namespace" istio -o jsonpath="{.data.mesh}" 2>/dev/null | grep "enableAutoMtls: true")
          if [[ -n "$mesh_config" ]]; then
            mtls_enabled=true
            break
          fi
        fi
      fi
    done
    
    if [[ "$service_mesh_exists" == true && "$mtls_enabled" == true ]]; then
      status="PASS"
      result="Service mesh is configured with mutual TLS (mTLS) for secure pod-to-pod communication."
    elif [[ "$service_mesh_exists" == true ]]; then
      status="WARN"
      result="Service mesh exists but mutual TLS (mTLS) may not be properly configured."
    elif [[ -n "$clusters" ]]; then
      status="FAIL"
      result="No service mesh with mutual TLS (mTLS) capability detected for container traffic security."
    else
      status="INFO"
      result="No clusters found for service mesh mTLS verification."
    fi
  else
    status="INFO"
    result="No GKE clusters found for service mesh mTLS check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-3.3",
    "description": "Container service mesh with mutual TLS (mTLS) enabled",
    "controls": "NIST-800-190-4.3.3,SC-8,SC-13,IA-3",
    "severity": "High", 
    "status": "$status",
    "result": "$result",
    "remediation": "Implement Anthos Service Mesh or Istio with strict mTLS policies for all pod-to-pod communication."
  }
EOF
  ))
  
  # 3.4 Kubernetes admission controllers
  # Check for validating and mutating admission controllers
  if [[ -n "$clusters" ]]; then
    local admission_controllers=false
    local policy_enforcement=false
    local opa_gatekeeper=false
    local kyverno=false
    
    for cluster in $clusters; do
      local zone=$(gcloud container clusters list --project="$project" --filter="name=$cluster" --format="value(zone)" 2>/dev/null)
      if [[ -n "$zone" ]]; then
        # Get credentials for the cluster
        gcloud container clusters get-credentials "$cluster" --zone="$zone" --project="$project" > /dev/null 2>&1
        
        # Check for validating/mutating webhook configurations
        local validating_webhooks=$(kubectl get validatingwebhookconfigurations 2>/dev/null)
        local mutating_webhooks=$(kubectl get mutatingwebhookconfigurations 2>/dev/null)
        
        if [[ -n "$validating_webhooks" || -n "$mutating_webhooks" ]]; then
          admission_controllers=true
        fi
        
        # Check for OPA Gatekeeper
        local gatekeeper_ns=$(kubectl get ns gatekeeper-system 2>/dev/null)
        local gatekeeper_pods=$(kubectl get pods -n gatekeeper-system 2>/dev/null)
        
        if [[ -n "$gatekeeper_ns" && -n "$gatekeeper_pods" ]]; then
          opa_gatekeeper=true
          policy_enforcement=true
        fi
        
        # Check for Kyverno
        local kyverno_ns=$(kubectl get ns kyverno 2>/dev/null)
        local kyverno_pods=$(kubectl get pods -n kyverno 2>/dev/null)
        
        if [[ -n "$kyverno_ns" && -n "$kyverno_pods" ]]; then
          kyverno=true
          policy_enforcement=true
        fi
        
        # Check for Binary Authorization in GKE
        local binary_auth=$(gcloud container clusters describe "$cluster" --zone="$zone" --project="$project" --format="value(binaryAuthorization.enabled)" 2>/dev/null)
        if [[ "$binary_auth" == "true" ]]; then
          policy_enforcement=true
        fi
      fi
    done
    
    if [[ "$admission_controllers" == true && "$policy_enforcement" == true ]]; then
      status="PASS"
      result="Kubernetes admission controllers are properly configured with policy enforcement ($([ "$opa_gatekeeper" == true ] && echo "OPA Gatekeeper, ")$([ "$kyverno" == true ] && echo "Kyverno, ")Binary Authorization)."
    elif [[ "$admission_controllers" == true ]]; then
      status="WARN"
      result="Kubernetes admission controllers exist but may lack robust policy enforcement mechanisms."
    else
      status="FAIL"
      result="Kubernetes admission controllers are not properly configured for security enforcement."
    fi
  else
    status="INFO"
    result="No GKE clusters found for admission controller check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-3.4",
    "description": "Kubernetes admission controllers enforce security policies",
    "controls": "NIST-800-190-4.3.4,CM-7,CM-14,CM-4,SA-10",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Implement policy enforcement with OPA Gatekeeper or Kyverno, and configure appropriate validating/mutating admission controllers."
  }
EOF
  ))
  
  # ================ 4. HOST OS SECURITY ================
  
  # 4.1 Host OS hardening
  # Check GKE clusters for shielded nodes, secure boot and integrity monitoring
  if [[ -n "$clusters" ]]; then
    local shielded_nodes=false
    local secure_boot=false
    local integrity_monitoring=false
    
    for cluster in $clusters; do
      local zone=$(gcloud container clusters list --project="$project" --filter="name=$cluster" --format="value(zone)" 2>/dev/null)
      if [[ -n "$zone" ]]; then
        # Check Shielded Nodes 
        local cluster_shielded=$(gcloud container clusters describe "$cluster" --zone="$zone" --project="$project" --format="value(shieldedNodes.enabled)" 2>/dev/null)
        if [[ "$cluster_shielded" == "true" ]]; then
          shielded_nodes=true
          # Shielded nodes implies secure boot and integrity monitoring are available
          # But we need to check node pools to see if they're specifically enabled
          
          # Get nodepools for detailed checks
          local nodepools=$(gcloud container node-pools list --cluster="$cluster" --zone="$zone" --project="$project" --format="value(name)" 2>/dev/null)
          for nodepool in $nodepools; do
            # Check secure boot
            local np_secure_boot=$(gcloud container node-pools describe "$nodepool" --cluster="$cluster" --zone="$zone" --project="$project" --format="value(config.shieldedInstanceConfig.enableSecureBoot)" 2>/dev/null)
            if [[ "$np_secure_boot" == "true" ]]; then
              secure_boot=true
            fi
            
            # Check integrity monitoring 
            local np_integrity=$(gcloud container node-pools describe "$nodepool" --cluster="$cluster" --zone="$zone" --project="$project" --format="value(config.shieldedInstanceConfig.enableIntegrityMonitoring)" 2>/dev/null)
            if [[ "$np_integrity" == "true" ]]; then
              integrity_monitoring=true
            fi
          done
        fi
      fi
    done
    
    if [[ "$shielded_nodes" == true && "$secure_boot" == true && "$integrity_monitoring" == true ]]; then
      status="PASS"
      result="GKE clusters use shielded nodes with secure boot and integrity monitoring enabled."
    elif [[ "$shielded_nodes" == true ]]; then
      status="WARN"
      result="GKE clusters use shielded nodes but secure boot and/or integrity monitoring may not be explicitly enabled."
    else
      status="FAIL"
      result="GKE clusters do not use shielded nodes or secure boot features."
    fi
  else
    status="INFO"
    result="No GKE clusters found for host OS hardening check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-4.1",
    "description": "Host OS is properly hardened and secured",
    "controls": "NIST-800-190-4.4.1,CM-6,CM-7,SC-7,SI-7",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Enable shielded nodes, secure boot, and integrity monitoring for all GKE clusters."
  }
EOF
  ))
  
  # 4.2 Host OS access restrictions
  # Check for node service account scopes and metadata concealment
  if [[ -n "$clusters" ]]; then
    local limited_scopes=false
    local metadata_concealed=false
    
    for cluster in $clusters; do
      local zone=$(gcloud container clusters list --project="$project" --filter="name=$cluster" --format="value(zone)" 2>/dev/null)
      if [[ -n "$zone" ]]; then
        # Get nodepools to check scopes
        local nodepools=$(gcloud container node-pools list --cluster="$cluster" --zone="$zone" --project="$project" --format="value(name)" 2>/dev/null)
        for nodepool in $nodepools; do
          # Check service account scopes - should not contain "cloud-platform"
          local np_scopes=$(gcloud container node-pools describe "$nodepool" --cluster="$cluster" --zone="$zone" --project="$project" --format="value(config.oauthScopes)" 2>/dev/null)
          if [[ -n "$np_scopes" && "$np_scopes" != *"cloud-platform"* ]]; then
            limited_scopes=true
          fi
        done
        
        # Check metadata concealment
        local metadata_disabled=$(gcloud container clusters describe "$cluster" --zone="$zone" --project="$project" --format="value(nodeConfig.metadata['disable-legacy-endpoints'])" 2>/dev/null)
        if [[ "$metadata_disabled" == "true" ]]; then
          metadata_concealed=true
        fi
      fi
    done
    
    if [[ "$limited_scopes" == true && "$metadata_concealed" == true ]]; then
      status="PASS"
      result="GKE clusters have properly limited node service account scopes and concealed metadata."
    elif [[ "$limited_scopes" == true || "$metadata_concealed" == true ]]; then
      status="WARN"
      result="GKE clusters have partially implemented host access restrictions."
    else
      status="FAIL"
      result="GKE clusters have overly permissive node service account scopes and/or exposed metadata."
    fi
  else
    status="INFO"
    result="No GKE clusters found for host OS access restriction check."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-4.2",
    "description": "Host OS access is properly restricted and secured",
    "controls": "NIST-800-190-4.4.2,AC-3,AC-5,AC-6,CM-7",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Configure limited OAuth scopes for node service accounts and enable metadata concealment."
  }
EOF
  ))
  
  # ================ 5. CONTAINER SUPPLY CHAIN SECURITY ================
  
  # 5.1 Build pipeline security
  # Check Cloud Build with Binary Authorization integration
  local cloudbuild_enabled=$(gcloud services list --project="$project" --filter="config.name=cloudbuild.googleapis.com" --format="value(config.name)" 2>/dev/null)
  if [[ -n "$cloudbuild_enabled" && -n "$binauth_enabled" ]]; then
    # Check for builds that include container analysis steps
    local build_triggers=$(gcloud builds triggers list --project="$project" --format="json" 2>/dev/null)
    if [[ -n "$build_triggers" && "$build_triggers" != "[]" ]]; then
      # Look for container analysis and vulnerability scanning steps
      if [[ "$build_triggers" == *"containeranalysis"* || "$build_triggers" == *"vulnerability"* || "$build_triggers" == *"kritis"* ]]; then
        status="PASS"
        result="Cloud Build is configured with container security scanning steps."
      else
        status="WARN"
        result="Cloud Build is configured but may not include container security scanning steps."
      fi
    else
      status="WARN"
      result="Cloud Build is enabled but no build triggers are configured."
    fi
  else
    status="FAIL"
    result="Cloud Build and/or Binary Authorization are not enabled for secure CI/CD pipeline."
  fi
  
  checks+=($(cat << EOF
  {
    "id": "CNTR-800-190-5.1",
    "description": "Container build pipeline includes security scanning and signing",
    "controls": "NIST-800-190-4.1.4,SA-10,CM-3,CM-14,SR-4",
    "severity": "High",
    "status": "$status",
    "result": "$result",
    "remediation": "Configure Cloud Build with container analysis steps and integrate with Binary Authorization."
  }
EOF
  ))
  
  # Convert all checks to JSON array
  local json_checks=$(for check in "${checks[@]}"; do echo "$check"; done | jq -s .)
  echo "$json_checks"
}

# Enhanced main function
main() {
  # Parse command line arguments
  parse_arguments "$@"
  
  # Check prerequisites
  check_prerequisites
  
  # Create timestamp for this run
  echo -e "${BLUE}Starting GCP FedRAMP compliance audit on $(date)${NC}"
  echo -e "${BLUE}FedRAMP level: $(echo $FEDRAMP_LEVEL | tr '[:lower:]' '[:upper:]')${NC}"
  
  # Run compliance report
  if [[ "$INVENTORY_ONLY" != "true" ]]; then
    generate_compliance_report "$PROJECT_ID"
  fi
  
  # Run inventory report
  if [[ "$REPORT_ONLY" != "true" ]]; then
    generate_inventory_report "$PROJECT_ID"
    
    # Add enhanced inventories
    inventory_org_policies "$PROJECT_ID"
    inventory_cloud_assets "$PROJECT_ID"
  fi
  
  # Create ZIP archive of results
  create_zip_archive
  
  echo -e "${GREEN}Audit completed successfully!${NC}"
  echo -e "${GREEN}Results are available in: $OUTPUT_DIR${NC}"
  
  # Show summary if verbose
  if [[ "$VERBOSE" == "true" ]] && [[ -f "$OUTPUT_DIR/${REPORT_PREFIX}_compliance_$PROJECT_ID.json" ]]; then
    echo -e "${BLUE}Compliance Summary:${NC}"
    jq -r '.summary' "$OUTPUT_DIR/${REPORT_PREFIX}_compliance_$PROJECT_ID.json"
  fi
}

# Run the main function
main "$@"