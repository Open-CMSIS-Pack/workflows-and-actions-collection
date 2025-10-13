#!/bin/bash

# Estimate cache size for new cache creation
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

# Cross-platform size calculation
get_path_size() {
  local path="$1"
  local size=0

  if [[ -e "$path" ]]; then
    # Try different approaches for different platforms
    if command -v du >/dev/null 2>&1; then
      # Most Unix-like systems (Linux, macOS, WSL, Git Bash)
      if du --version >/dev/null 2>&1; then
        # GNU du (Linux)
        size=$(du -sm "$path" 2>/dev/null | cut -f1 || echo "0")
      else
        # BSD du (macOS)
        size=$(du -sm "$path" 2>/dev/null | awk '{print $1}' || echo "0")
      fi
    elif [[ -f "$path" ]]; then
      # Fallback for single files using stat
      if stat --version >/dev/null 2>&1; then
        # GNU stat (Linux)
        size=$(stat -c%s "$path" 2>/dev/null || echo "0")
        size=$((size / 1024 / 1024))  # Convert to MB
      elif stat -f%z "$path" >/dev/null 2>&1; then
        # BSD stat (macOS)
        size=$(stat -f%z "$path" 2>/dev/null || echo "0")
        size=$((size / 1024 / 1024))  # Convert to MB
      fi
    fi
  fi

  # Ensure we return a number
  if ! [[ "$size" =~ ^[0-9]+$ ]]; then
    size=0
  fi

  echo "$size"
}

main() {
  local paths="$1"

  log_info "Estimating cache size for new cache..."

  local total_size=0
  local processed_paths

  # Process paths using cross-platform function
  processed_paths=$(process_paths "$paths")

  # Check if we have any paths to process
  if [[ -z "$processed_paths" ]]; then
    log_warning "No paths provided for size estimation"
    output_set "estimated-size-mb" "0"
    exit 0
  fi

  # Calculate size for each path
  local path
  while IFS= read -r path || [[ -n "$path" ]]; do
    if [[ -n "$path" ]]; then
      if [[ -e "$path" ]]; then
        local size
        size=$(get_path_size "$path")
        total_size=$((total_size + size))
        log_info "Path $path: ${size}MB"
      else
        log_warning "Path not found: $path"
      fi
    fi
  done <<EOF
$processed_paths
EOF

  # Add 25% buffer for compression variations and metadata
  local estimated_mb=$((total_size + (total_size * 25 / 100)))
  if [[ $estimated_mb -eq 0 && $total_size -gt 0 ]]; then
    estimated_mb=1  # Minimum 1MB estimate
  fi

  log_info "Calculated size: ${total_size}MB"
  log_info "With buffer (25%): ${estimated_mb}MB"

  output_set "estimated-size-mb" "$estimated_mb"
  log_success "Estimated cache size: ${estimated_mb}MB"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
