#!/bin/bash

# Generate cache operation summary
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib/common.sh"

main() {
  log_section "Generating cache operation summary"

  # Get environment variables
  local cache_strategy_result="${CACHE_STRATEGY_RESULT:-unknown}"
  local cache_needed="${CACHE_NEEDED:-false}"
  local cache_exists="${CACHE_EXISTS:-false}"
  local cache_hit="${CACHE_HIT:-false}"
  local cache_key="${CACHE_KEY:-unknown}"
  local cache_matched_key="${CACHE_MATCHED_KEY:-}"
  local cleanup_performed="${CLEANUP_PERFORMED:-false}"
  local space_freed_mb="${SPACE_FREED_MB:-0}"
  local repo_cleanup_performed="${REPO_CLEANUP_PERFORMED:-false}"
  local repo_space_freed_mb="${REPO_SPACE_FREED_MB:-0}"
  local estimated_size_mb="${ESTIMATED_SIZE_MB:-}"

  # Generate summary for GitHub Step Summary
  output_append "## Smart Cache Summary"
  output_append ""

  # Repository cleanup status (always show if performed)
  if [[ "$repo_cleanup_performed" == "true" ]]; then
    output_append "**Repository Cleanup Performed**"
    output_append "- **Space Freed:** ${repo_space_freed_mb}MB using LRU strategy"
    output_append "- **Reason:** Repository cache size exceeded limits"
    output_append ""
  fi

  if [[ "$cache_needed" == "true" ]]; then
    output_append "**Cache operation performed**"
    output_append "- **Key:** \`$cache_key\`"
    output_append "- **Cache Hit:** $cache_hit"

    if [[ -n "$cache_matched_key" ]]; then
      output_append "- **Matched Key:** \`$cache_matched_key\`"
    fi

    if [[ "$cache_exists" == "true" ]]; then
      output_append "- **Cache Status:** Restored existing cache"
    elif [[ "$cleanup_performed" == "true" ]]; then
      output_append "- **Pre-cleanup:** Freed ${space_freed_mb}MB for new cache"
    fi

    if [[ -n "$estimated_size_mb" ]]; then
      output_append "- **Estimated Size:** ${estimated_size_mb}MB"
    fi
  else
    output_append "**Cache operation skipped**"
    output_append "- **Reason:** $cache_strategy_result"
  fi

  # Additional details for console output
  log_section "Cache Operation Summary"
  log_info "Strategy Result: $cache_strategy_result"
  log_info "Cache Needed: $cache_needed"
  log_info "Cache Exists: $cache_exists"
  log_info "Cache Hit: $cache_hit"

  if [[ "$cleanup_performed" == "true" ]]; then
    log_info "Pre-cleanup: Freed ${space_freed_mb}MB"
  fi

  if [[ "$repo_cleanup_performed" == "true" ]]; then
    log_info "Repository cleanup: Freed ${repo_space_freed_mb}MB"
  fi

  log_success "Summary generation completed"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
