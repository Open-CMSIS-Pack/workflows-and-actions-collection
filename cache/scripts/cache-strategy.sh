#!/bin/bash

# Determine cache strategy based on inputs and existing cache state
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib/common.sh"

# Cross-platform trim function
trim_whitespace() {
  local var="$1"
  # Remove leading whitespace
  var="${var#"${var%%[![:space:]]*}"}"
  # Remove trailing whitespace
  var="${var%"${var##*[![:space:]]}"}"
  echo "$var"
}

# Cross-platform path processing
process_paths() {
  local paths_input="$1"
  local -a path_list=()

  # Handle different line endings (Windows/Unix)
  local cleaned_paths
  cleaned_paths=$(echo "$paths_input" | tr -d '\r')

  # Process line by line
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(trim_whitespace "$line")
    if [[ -n "$line" ]]; then
      path_list+=("$line")
    fi
  done <<EOF
$cleaned_paths
EOF

  # If no paths found, try alternative parsing
  if [[ ${#path_list[@]} -eq 0 && -n "$cleaned_paths" ]]; then
    # Try space/comma separation
    local IFS_OLD="$IFS"
    IFS=$' \t\n,'
    for item in $cleaned_paths; do
      item=$(trim_whitespace "$item")
      [[ -n "$item" ]] && path_list+=("$item")
    done
    IFS="$IFS_OLD"
  fi

  # Return paths (one per line)
  printf '%s\n' "${path_list[@]}"
}

main() {
  local lookup_only="$1"
  local cache_hit="$2"
  local paths="$3"

  log_info "Determining cache strategy..."

  # If user requested lookup-only, just use the existing check
  if [[ "$lookup_only" == "true" ]]; then
    output_set "cache-needed" "true"
    output_set "cache-exists" "$cache_hit"
    output_set "reason" "lookup-only-requested"
    log_success "Lookup-only mode requested"
    exit 0
  fi

  # Check if cache already exists
  if [[ "$cache_hit" == "true" ]]; then
    output_set "cache-needed" "true"
    output_set "cache-exists" "true"
    output_set "reason" "cache-exists-restore-only"
    log_success "Cache exists - will restore without cleanup"
    exit 0
  fi

  # Cache doesn't exist, check if paths exist for new cache
  log_info "No existing cache found. Checking paths for new cache..."

  local cache_needed=false
  local missing_paths=""

  # Process paths using cross-platform function
  local processed_paths
  processed_paths=$(process_paths "$paths")

  # Check each path
  local path
  while IFS= read -r path || [[ -n "$path" ]]; do
    if [[ -n "$path" ]]; then
      # Cross-platform path existence check
      if [[ -e "$path" ]] || [[ -d "$path" ]] || [[ -f "$path" ]] || ls "$path" >/dev/null 2>&1; then
        cache_needed=true
        log_info "Found: $path"
      else
        missing_paths="${missing_paths} $path"
        log_warning "Missing: $path"
      fi
    fi
  done <<EOF
$processed_paths
EOF

  if [[ "$cache_needed" == "true" ]]; then
    output_set "cache-needed" "true"
    output_set "cache-exists" "false"
    output_set "reason" "paths-exist-new-cache"
    log_success "Paths found - will create new cache"
  else
    output_set "cache-needed" "false"
    output_set "cache-exists" "false"
    output_set "reason" "no-paths-found"
    log_warning "No paths found to cache:$missing_paths"
  fi
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
