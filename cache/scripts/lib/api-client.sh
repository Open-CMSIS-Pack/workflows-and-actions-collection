#!/bin/bash

# GitHub API client for cache operations
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common.sh"

# Check if required tools are available
check_dependencies() {
  local missing_tools=()

  if ! command -v gh &> /dev/null; then
    missing_tools+=("gh (GitHub CLI)")
  fi

  if ! command -v jq &> /dev/null; then
    missing_tools+=("jq")
  fi

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_warning "Missing required tools: ${missing_tools[*]}"
    return 1
  fi

  return 0
}

# Retry GitHub API calls with exponential backoff
retry_gh_api() {
  local retries=5
  local delay=3
  local cmd=("$@")

  for ((i=0; i<retries; i++)); do
    if output=$("${cmd[@]}" 2>&1); then
      echo "$output"
      return 0
    else
      local exit_code=$?
      log_debug "API call failed (attempt $((i+1))/$retries): $output"

      # Don't retry on 404 (cache already deleted by another job)
      if echo "$output" | grep -q "404\|Not Found"; then
        log_info "Cache already deleted by another job - continuing"
        return 1
      fi

      if [[ $i -lt $((retries-1)) ]]; then
        # Add jitter to reduce thundering herd
        local jitter=$((RANDOM % 3))
        local total_delay=$((delay + jitter))
        log_info "Retrying in ${total_delay}s..."
        sleep $total_delay
        delay=$((delay * 2))
      fi
    fi
  done
  return 1
}

# Get repository caches
get_repository_caches() {
  local repo="$1"

  retry_gh_api gh api "repos/$repo/actions/caches" --paginate \
    -q '.actions_caches[] | {key: .key, size_in_bytes: .size_in_bytes, created_at: .created_at, last_accessed_at: .last_accessed_at, id: .id}'
}

# Delete a specific cache
delete_cache() {
  local repo="$1"
  local cache_id="$2"

  retry_gh_api gh api "repos/$repo/actions/caches/$cache_id" -X DELETE
}

# Get cache statistics
get_cache_stats() {
  local cache_list="$1"
  local total_size=0
  local cache_count=0

  while IFS= read -r cache; do
    if [[ -n "$cache" ]]; then
      size=$(echo "$cache" | jq -r '.size_in_bytes // 0' 2>/dev/null || echo "0")
      total_size=$((total_size + size))
      cache_count=$((cache_count + 1))
    fi
  done <<< "$cache_list"

  echo "$total_size,$cache_count"
}

# Filter caches by criteria
filter_caches() {
  local cache_list="$1"
  local exclude_key="$2"

  echo "$cache_list" | jq -s --arg key "$exclude_key" \
    'map(select(.key != $key))' 2>/dev/null || echo "[]"
}

# Sort caches by LRU (Least Recently Used)
sort_caches_lru() {
  local cache_list="$1"

  echo "$cache_list" | jq 'sort_by(.last_accessed_at // .created_at)' 2>/dev/null || echo "[]"
}
