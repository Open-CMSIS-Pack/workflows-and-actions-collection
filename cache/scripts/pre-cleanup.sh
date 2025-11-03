#!/bin/bash

# Pre-cache cleanup logic with LRU strategy
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/api-client.sh"

# Perform cleanup with proper variable persistence across subshells
perform_cleanup() {
  local sorted_candidates="$1"
  local space_needed="$2"
  local dry_run="$3"
  local current_key="$4"

  local space_freed=0
  local deleted_count=0

  # Better cross-platform temp directory
  local temp_dir
  temp_dir=$(get_temp_dir)
  local temp_file="$temp_dir/cache_cleanup_stats_$$"
  echo "0,0" > "$temp_file"

  # Process each candidate
  local candidate_list
  candidate_list=$(echo "$sorted_candidates" | jq -r '.[]? | @base64' 2>/dev/null || true)

  if [[ -n "$candidate_list" ]]; then
    echo "$candidate_list" | while IFS= read -r cache_b64; do
      [[ -z "$cache_b64" ]] && continue

      # Read current stats from temp file
      if [[ -f "$temp_file" ]]; then
        current_stats=$(cat "$temp_file" 2>/dev/null || echo "0,0")
        space_freed=$(echo "$current_stats" | cut -d',' -f1)
        deleted_count=$(echo "$current_stats" | cut -d',' -f2)
      fi

      if [[ $space_freed -ge $space_needed ]]; then
        log_success "Cleanup goals met"
        break
      fi

      cache=$(decode_base64 "$cache_b64" || continue)
      cache_id=$(echo "$cache" | jq -r '.id // empty' 2>/dev/null || continue)
      key=$(echo "$cache" | jq -r '.key // empty' 2>/dev/null || continue)
      size=$(echo "$cache" | jq -r '.size_in_bytes // 0' 2>/dev/null || echo "0")
      last_accessed=$(echo "$cache" | jq -r '.last_accessed_at // .created_at // "unknown"' 2>/dev/null || echo "unknown")

      if [[ -z "$cache_id" || -z "$key" ]]; then
        continue
      fi

      if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would delete: $key ($(format_bytes $size), last accessed: $last_accessed)"
        space_freed=$((space_freed + size))
        deleted_count=$((deleted_count + 1))
      else
        log_info "🗑️ Deleting: $key ($(format_bytes $size), last accessed: $last_accessed)"

        if delete_cache "$GITHUB_REPOSITORY" "$cache_id"; then
          log_success "Deleted successfully"
          space_freed=$((space_freed + size))
          deleted_count=$((deleted_count + 1))
        else
          log_warning "Failed to delete cache $cache_id"
        fi
      fi

      # Write updated stats to temp file
      echo "$space_freed,$deleted_count" > "$temp_file"
    done
  fi

  # Read final stats from temp file
  if [[ -f "$temp_file" ]]; then
    final_stats=$(cat "$temp_file" 2>/dev/null || echo "0,0")
    space_freed=$(echo "$final_stats" | cut -d',' -f1)
    deleted_count=$(echo "$final_stats" | cut -d',' -f2)
    rm -f "$temp_file" 2>/dev/null || true
  fi

  echo "$space_freed,$deleted_count"
}

main() {
  log_section "Starting pre-cache cleanup analysis (LRU strategy)"

  # Initialize outputs
  output_set "cleanup-performed" "false"
  output_set "space-freed-mb" "0"

  # Check dependencies
  if ! check_dependencies; then
    log_warning "Required tools not available. Skipping cleanup."
    exit 0
  fi

  # Get environment variables
  local max_size_gb="${MAX_SIZE_GB:-8}"
  local estimated_size_mb="${ESTIMATED_SIZE_MB:-0}"
  local cleanup_threshold="80"
  local current_key="${CURRENT_KEY}"
  local dry_run="${DRY_RUN:-false}"

  # Get current cache status
  log_section "Analyzing current cache usage"

  local cache_list
  cache_list=$(get_repository_caches "$GITHUB_REPOSITORY") || {
    log_success "No existing caches found or API unavailable. No cleanup needed."
    exit 0
  }

  if [[ -z "$cache_list" ]]; then
    log_success "No existing caches found. No cleanup needed."
    exit 0
  fi

  # Calculate current total size
  local cache_stats
  cache_stats=$(get_cache_stats "$cache_list")
  local total_size=$(echo "$cache_stats" | cut -d',' -f1)
  local cache_count=$(echo "$cache_stats" | cut -d',' -f2)

  # Cross-platform arithmetic (avoiding floating point)
  local max_size_bytes=$((max_size_gb * 1024 * 1024 * 1024))
  local threshold_bytes=$((max_size_bytes * cleanup_threshold / 100))
  local estimated_new_size_bytes=$((estimated_size_mb * 1024 * 1024))
  local projected_size=$((total_size + estimated_new_size_bytes))

  log_section "Cache Analysis"
  log_info "Current caches: $cache_count"
  log_info "Current total size: $(format_bytes $total_size)"
  log_info "Maximum allowed: $(format_bytes $max_size_bytes)"
  log_info "Cleanup threshold (80%): $(format_bytes $threshold_bytes)"
  log_info "Estimated new cache: $(format_bytes $estimated_new_size_bytes)"
  log_info "Projected total: $(format_bytes $projected_size)"

  # Determine if cleanup is needed
  local cleanup_needed=false
  local cleanup_reason=""

  if [[ $projected_size -gt $max_size_bytes ]]; then
    cleanup_needed=true
    cleanup_reason="projected size exceeds maximum"
  elif [[ $total_size -gt $threshold_bytes ]]; then
    cleanup_needed=true
    cleanup_reason="current size exceeds threshold"
  fi

  if [[ "$cleanup_needed" != "true" ]]; then
    log_success "No cleanup needed - $cleanup_reason"
    exit 0
  fi

  log_warning "Cleanup needed: $cleanup_reason"

  # Filter caches for cleanup (exclude current key)
  local cleanup_candidates
  cleanup_candidates=$(filter_caches "$cache_list" "$current_key")

  local candidate_count
  candidate_count=$(echo "$cleanup_candidates" | jq '. | length' 2>/dev/null || echo "0")

  if [[ $candidate_count -eq 0 ]]; then
    log_warning "No cleanup candidates found (excluding current key)"
    exit 0
  fi

  # Sort candidates by LRU (Least Recently Used)
  local sorted_candidates
  sorted_candidates=$(sort_caches_lru "$cleanup_candidates")

  log_info "Found $candidate_count cleanup candidates using LRU strategy"

  # Calculate how much space we need to free
  local space_needed=$((projected_size - threshold_bytes))
  if [[ $space_needed -lt 0 ]]; then
    space_needed=0
  fi

  log_info "Target: Free at least $(format_bytes $space_needed)"

  # Perform cleanup
  local cleanup_result
  cleanup_result=$(perform_cleanup "$sorted_candidates" "$space_needed" "$dry_run" "$current_key")
  local space_freed=$(echo "$cleanup_result" | cut -d',' -f1)
  local deleted_count=$(echo "$cleanup_result" | cut -d',' -f2)

  # Update outputs
  local space_freed_mb=$((space_freed / 1024 / 1024))
  if [[ $deleted_count -gt 0 ]]; then
    output_set "cleanup-performed" "true"
  fi
  output_set "space-freed-mb" "$space_freed_mb"

  # Final verification
  local final_projected_size=$((total_size - space_freed + estimated_new_size_bytes))

  log_section "Cleanup Results"
  if [[ "$dry_run" == "true" ]]; then
    log_info "Dry run completed. Would have freed $(format_bytes $space_freed) from $deleted_count caches"
    log_info "Projected size after cleanup: $(format_bytes $final_projected_size)"
  else
    log_success "Cleanup completed!"
    log_info "Deleted caches: $deleted_count"
    log_info "Space freed: $(format_bytes $space_freed)"
    log_info "Final projected size: $(format_bytes $final_projected_size)"

    if [[ $final_projected_size -gt $max_size_bytes ]]; then
      log_warning "Warning: Projected size may still exceed limit after cleanup"
    else
      log_success "New cache will fit within size limits"
    fi
  fi
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
