#!/bin/bash
set -euo pipefail

# Source common configuration
source /usr/local/bin/config.sh

# Function: track commits for extensions
track_extension_commit() {
  local dir="$1"
  local name=$(basename "$dir")
  local last_commit_file="$LAST_DIR/${name}.commit"
  local new_commit old_commit branch

  # Get new commit
  new_commit=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || {
    log "ERROR" "Failed to get commit hash for $name"
    return 1
  }

  # Compare with old commit
  old_commit=""
  if [ -f "$last_commit_file" ]; then
    old_commit=$(<"$last_commit_file")
  fi

  if [ "$new_commit" != "$old_commit" ]; then
    echo "$new_commit" >"$last_commit_file"
    log "INFO" "New commit detected for $name: $new_commit"
    return 0 # Changes detected
  else
    log "INFO" "No changes in $name (commit: $new_commit)"
    return 1 # No changes
  fi
}

# Function: install extension dependencies
install_extension_deps() {
  local dir="$1"
  local name=$(basename "$dir")

  if [ -f "$dir/requirements.txt" ]; then
    log "INFO" "Installing dependencies for $name"
    if uv pip install -r "$dir/requirements.txt"; then
      log "INFO" "Successfully installed dependencies for $name"
      return 0
    else
      log "WARN" "Failed to install dependencies for $name"
      return 1
    fi
  else
    log "INFO" "No requirements.txt found for $name"
    return 0
  fi
}

# Parse extensions from config file
EXTENSIONS=()
log "INFO" "Parsing extensions configuration"

while IFS= read -r line; do
  line="${line%%[#;]*}"
  line="${line##+([[:space:]])}"
  line="${line%%+([[:space:]])}"
  [[ -z "$line" || "$line" =~ ^\[ ]] && continue
  EXTENSIONS+=("$line")
done </app/extensions.conf

log "INFO" "== Processing Extensions =="
log "INFO" "Found ${#EXTENSIONS[@]} extensions to process"

for url in "${EXTENSIONS[@]}"; do
  name=$(basename "$url" .git)
  target="$CUSTOM_DIR/$name"

  log "INFO" "Processing extension: $name from $url"

  # Clone or update the repository
  if ! git_clone_or_update "$target" "$url"; then
    log "WARN" "Failed to update/clone extension: $name, skipping dependency installation"
    continue
  fi

  # Check if there are new commits
  if track_extension_commit "$target"; then
    # Only install dependencies if there are new commits
    install_extension_deps "$target" || log "WARN" "Dependency installation issues for $name, but continuing"
  else
    log "INFO" "No changes detected for $name, skipping dependency installation"
  fi
done

log "INFO" "== Extensions initialization complete =="
