#!/bin/bash

# Cross-platform utilities for Smart Cache action
set -euo pipefail

# Cross-platform function to format bytes to human readable
format_bytes() {
  local bytes=$1
  if (( bytes >= 1073741824 )); then
    echo "$(( bytes / 1073741824 ))GB"
  elif (( bytes >= 1048576 )); then
    echo "$(( bytes / 1048576 ))MB"
  elif (( bytes >= 1024 )); then
    echo "$(( bytes / 1024 ))KB"
  else
    echo "${bytes}B"
  fi
}

# Cross-platform base64 decode
decode_base64() {
  if command -v base64 >/dev/null 2>&1; then
    if echo "dGVzdA==" | base64 --decode >/dev/null 2>&1; then
      echo "$1" | base64 --decode 2>/dev/null
    elif echo "dGVzdA==" | base64 -d >/dev/null 2>&1; then
      echo "$1" | base64 -d 2>/dev/null
    else
      echo "base64 decode not supported" >&2
      return 1
    fi
  else
    echo "base64 command not found" >&2
    return 1
  fi
}

# Cross-platform temp directory
get_temp_dir() {
  echo "${RUNNER_TEMP:-${TMPDIR:-${TMP:-/tmp}}}"
}

# Cross-platform array handling (macOS Bash 3.2 compatible)
process_multiline_input() {
  local input="$1"
  local callback="$2"
  local count=0

  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      # Store each line with index for later processing
      eval "${callback}_$count=\"\$line\""
      count=$((count + 1))
    fi
  done <<< "$input"

  echo "$count"
}

# Cross-platform whitespace trimming
trim_whitespace() {
  echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Output helper functions
output_set() {
  echo "$1=$2" >> "$GITHUB_OUTPUT"
}

output_append() {
  local message="${1:-}"  # Default to empty if $1 not provided
  echo "$message" >> "$GITHUB_STEP_SUMMARY"
}

# Logging helpers
log_info() {
  echo "info:  $*"
}

log_success() {
  echo "success: $*"
}

log_warning() {
  echo "warning:  $*"
}

log_error() {
  echo "error: $*"
}

log_section() {
  echo ""
  echo "$*"
}

log_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo "DEBUG: $*"
  fi
}
