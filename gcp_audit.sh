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