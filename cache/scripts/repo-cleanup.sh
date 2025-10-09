#!/bin/bash

# Repository cache health check and cleanup
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/api-client.sh"

# Safe numeric validation function
ensure_numeric() {
  local value="$1"
  # Extract only digits, default to 0 if none found
  local numeric_value=$(echo "$value" | grep -o '^[0-9]*' | head -1)
  if [[ -z "$numeric_value" ]]; then
    echo "0"
  else
    echo "$numeric_value"
  fi
}

# Function to safely delete cache with race condition handling
safe_delete_cache() {
  local cache_id="$1"
  local cache_key="$2"
  local cache_size="$3"
  local dry_run="$4"

  log_info "Attempting to delete: $cache_key ($(format_bytes $cache_size))"

  if [[ "$dry_run" == "true" ]]; then
    log_info "[DRY RUN] Would delete cache $cache_id"
    return 0
  fi

  if delete_cache "$GITHUB_REPOSITORY" "$cache_id"; then
    log_success "Successfully deleted cache $cache_id"
    return 0
  else
    log_warning "Cache $cache_id may have been deleted by another job"
    return 1
  fi
}

# Perform repository cleanup attempt
perform_repo_cleanup_attempt() {
  local attempt="$1"
  local max_size_bytes="$2"
  local threshold_bytes="$3"
  local current_key="$4"
  local dry_run="$5"
  local max_deletions_per_attempt=5

  log_section "Cleanup attempt $attempt"

  # Get fresh cache list for each attempt
  local cache_list
  cache_list=$(get_repository_caches "$GITHUB_REPOSITORY") || {
    log_success "No caches found or API unavailable."
    echo "0,0,true"
    return 0
  }

  if [[ -z "$cache_list" ]]; then
    log_success "No caches found."
    echo "0,0,true"
    return 0
  fi

  # Calculate current total repository cache size
  local cache_stats
  cache_stats=$(get_cache_stats "$cache_list")
  local total_size=$(echo "$cache_stats" | cut -d',' -f1)
  local cache_count=$(echo "$cache_stats" | cut -d',' -f2)

  log_info "Repository Cache Analysis (Attempt $attempt):"
  log_info "Total caches: $cache_count"
  log_info "Current total size: $(format_bytes $total_size)"
  log_info "Maximum allowed: $(format_bytes $max_size_bytes)"
  log_info "Cleanup threshold (80%): $(format_bytes $threshold_bytes)"

  # Check if cleanup is still needed
  local cleanup_needed=false
  local cleanup_reason=""

  if [[ $total_size -gt $max_size_bytes ]]; then
    cleanup_needed=true
    cleanup_reason="repository cache size exceeds maximum limit"
  elif [[ $total_size -gt $threshold_bytes ]]; then
    cleanup_needed=true
    cleanup_reason="repository cache size exceeds 80% threshold"
  fi

  if [[ "$cleanup_needed" != "true" ]]; then
    log_success "Repository cache size is now healthy"
    echo "0,0,true"
    return 0
  fi

  log_warning "Repository cleanup needed: $cleanup_reason"

  # Filter and sort caches for cleanup
  local cleanup_candidates
  cleanup_candidates=$(filter_caches "$cache_list" "$current_key")

  local candidate_count
  candidate_count=$(echo "$cleanup_candidates" | jq '. | length' 2>/dev/null || echo "0")

  if [[ $candidate_count -eq 0 ]]; then
    log_warning "No cleanup candidates found (all caches match current key)"
    echo "0,0,true"
    return 0
  fi

  local sorted_candidates
  sorted_candidates=$(sort_caches_lru "$cleanup_candidates")

  log_info "Found $candidate_count cleanup candidates using LRU strategy"

  # Calculate how much space we need to free to get under threshold
  local space_needed=$((total_size - threshold_bytes))
  if [[ $space_needed -lt 0 ]]; then
    space_needed=0
  fi

  log_info "Target: Free at least $(format_bytes $space_needed) to get under 80% threshold"

  # Process deletions (limit to prevent too much deletion in one attempt)
  local deletions_this_attempt=0
  local space_freed_this_attempt=0

  local temp_dir
  temp_dir=$(get_temp_dir)
  local temp_file="$temp_dir/repo_cleanup_stats_$$"
  echo "0,0" > "$temp_file"

  local candidate_list
  candidate_list=$(echo "$sorted_candidates" | jq -r '.[]? | @base64' 2>/dev/null || true)

  if [[ -n "$candidate_list" ]]; then
    echo "$candidate_list" | while IFS= read -r cache_b64 && [[ $deletions_this_attempt -lt $max_deletions_per_attempt ]]; do
      [[ -z "$cache_b64" ]] && continue

      # Read current stats from temp file
      if [[ -f "$temp_file" ]]; then
        current_stats=$(cat "$temp_file" 2>/dev/null || echo "0,0")
        space_freed_this_attempt=$(echo "$current_stats" | cut -d',' -f1)
        deletions_this_attempt=$(echo "$current_stats" | cut -d',' -f2)
      fi

      if [[ $space_freed_this_attempt -ge $space_needed ]]; then
        log_success "Repository cleanup goals met"
        break
      fi

      cache=$(decode_base64 "$cache_b64" || continue)
      cache_id=$(echo "$cache" | jq -r '.id // empty' 2>/dev/null || continue)
      key=$(echo "$cache" | jq -r '.key // empty' 2>/dev/null || continue)
      size=$(echo "$cache" | jq -r '.size_in_bytes // 0' 2>/dev/null || echo "0")

      if [[ -z "$cache_id" || -z "$key" ]]; then
        continue
      fi

      # Add small delay between deletions to reduce race conditions
      if [[ $deletions_this_attempt -gt 0 ]]; then
        sleep 1
      fi

      if safe_delete_cache "$cache_id" "$key" "$size" "$dry_run"; then
        space_freed_this_attempt=$((space_freed_this_attempt + size))
        deletions_this_attempt=$((deletions_this_attempt + 1))
      fi

      # Write updated stats to temp file
      echo "$space_freed_this_attempt,$deletions_this_attempt" > "$temp_file"
    done
  fi

  # Read final stats from temp file
  if [[ -f "$temp_file" ]]; then
    final_stats=$(cat "$temp_file" 2>/dev/null || echo "0,0")
    space_freed_this_attempt=$(echo "$final_stats" | cut -d',' -f1)
    deletions_this_attempt=$(echo "$final_stats" | cut -d',' -f2)
    rm -f "$temp_file" 2>/dev/null || true
  fi

  log_info "Attempt $attempt results:"
  log_info "Deleted: $deletions_this_attempt caches"
  log_info "Freed: $(format_bytes $space_freed_this_attempt)"

  # Determine if we should continue
  local should_break="false"
  if [[ $deletions_this_attempt -eq 0 ]]; then
    log_warning "No progress made in this attempt, stopping cleanup"
    should_break="true"
  fi

  echo "$space_freed_this_attempt,$deletions_this_attempt,$should_break"
}

main() {
  log_section "Checking repository cache health"

  # Get environment variables
  local max_size_gb="${MAX_SIZE_GB:-8}"
  local cleanup_threshold="80"
  local current_key="${CURRENT_KEY}"
  local dry_run="${DRY_RUN:-false}"
  local job_id="${GITHUB_RUN_ID:-unknown}"

  log_info "Job ID: $job_id (for race condition protection)"

  # Initialize outputs
  output_set "repo-cleanup-performed" "false"
  output_set "repo-space-freed-mb" "0"

  # Check dependencies
  if ! check_dependencies; then
    log_warning "Required tools not available. Skipping repository cleanup."
    exit 0
  fi

  # Calculate size limits
  local max_size_bytes=$((max_size_gb * 1024 * 1024 * 1024))
  local threshold_bytes=$((max_size_bytes * cleanup_threshold / 100))

  # Main cleanup logic with race condition protection
  local max_cleanup_attempts=3
  local cleanup_attempt=0
  local total_space_freed=0
  local total_deleted_count=0

  while [[ $cleanup_attempt -lt $max_cleanup_attempts ]]; do
    cleanup_attempt=$((cleanup_attempt + 1))

    local attempt_result
    attempt_result=$(perform_repo_cleanup_attempt "$cleanup_attempt" "$max_size_bytes" "$threshold_bytes" "$current_key" "$dry_run")

    local space_freed_this_attempt=0
    local deletions_this_attempt=0
    local should_break="false"

    if [[ -n "$attempt_result" ]]; then
      # Extract and validate numeric values
      space_freed_this_attempt=$(ensure_numeric "$(echo "$attempt_result" | cut -d',' -f1)")
      deletions_this_attempt=$(ensure_numeric "$(echo "$attempt_result" | cut -d',' -f2)")
      should_break=$(echo "$attempt_result" | cut -d',' -f3)
    fi

    # Update totals with validated numeric values
    total_space_freed=$((total_space_freed + space_freed_this_attempt))
    total_deleted_count=$((total_deleted_count + deletions_this_attempt))

    # If we deleted something, wait a moment for GitHub's cache to update
    if [[ $deletions_this_attempt -gt 0 ]]; then
      log_info "Waiting for cache state to update..."
      sleep 5
    fi

    # Check if we should break
    if [[ "$should_break" == "true" ]]; then
      break
    fi
  done

  # Update outputs
  local space_freed_mb=$((total_space_freed / 1024 / 1024))
  if [[ $total_deleted_count -gt 0 ]]; then
    output_set "repo-cleanup-performed" "true"
  fi
  output_set "repo-space-freed-mb" "$space_freed_mb"

  # Final summary
  log_section "Final cleanup summary"
  if [[ "$dry_run" == "true" ]]; then
    log_info "[DRY RUN] Would have freed: $(format_bytes $total_space_freed)"
    log_info "[DRY RUN] Would have deleted: $total_deleted_count caches"
  else
    log_info "Total space freed: $(format_bytes $total_space_freed)"
    log_info "Total caches deleted: $total_deleted_count"
    log_info "Cleanup attempts: $cleanup_attempt"
  fi
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
