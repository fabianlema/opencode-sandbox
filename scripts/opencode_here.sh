#!/bin/bash

# opencode_here - Helper function to run opencode in Docker sandbox
# Usage: source this file, then run 'opencode_here' or 'oh' alias

# Configuration
OPENCODE_SANDBOX_REPO="fabianlema/opencode-sandbox"
UPDATE_CHECK_INTERVAL=86400  # 24 hours in seconds

# Check for script updates (runs in background to not block)
__opencode_check_update() {
  local version_file="$HOME/.config/opencode-sandbox/.version"
  local current_time=$(date +%s)
  local last_check=0
  local remote_hash=""
  
  # Read last check timestamp
  if [[ -f "$version_file" ]]; then
    last_check=$(head -1 "$version_file" 2>/dev/null || echo 0)
    remote_hash=$(tail -1 "$version_file" 2>/dev/null || echo "")
  fi
  
  # Only check once per day
  if (( current_time - last_check < UPDATE_CHECK_INTERVAL )); then
    return 0
  fi
  
  # Check remote version in background
  (
    local latest_hash=$(curl -s "https://api.github.com/repos/${OPENCODE_SANDBOX_REPO}/commits/main" 2>/dev/null | grep -o '"sha": "[^"]*"' | head -1 | cut -d'"' -f4)
    if [[ -n "$latest_hash" && "$latest_hash" != "$remote_hash" ]]; then
      echo "${current_time}" > "$version_file"
      echo "${latest_hash}" >> "$version_file"
      # Create marker file to show update available
      touch "$HOME/.config/opencode-sandbox/.update-available"
    else
      # Update timestamp even if no new version
      echo "${current_time}" > "$version_file"
      [[ -n "$remote_hash" ]] && echo "${remote_hash}" >> "$version_file"
    fi
  ) &>/dev/null &
}

function __opencode_here() {
  # Auto-detect GitHub user/org from git remote or gh CLI
  local github_user=""

  # Try to get from gh CLI first
  if command -v gh &>/dev/null; then
    github_user=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null)
  fi

  # Fallback: try to extract from git remote
  if [[ -z "$github_user" ]]; then
    github_user=$(git remote get-url origin 2>/dev/null | sed -n 's/.*github.com[:/]\([^/]*\).*/\1/p')
  fi

  # Final fallback: use env variable or prompt
  if [[ -z "$github_user" ]]; then
    if [[ -n "$GITHUB_USER" ]]; then
      github_user="$GITHUB_USER"
    else
      echo "❌ Error: Could not detect GitHub username. Please set GITHUB_USER environment variable."
      echo "   Example: export GITHUB_USER=yourusername"
      return 1
    fi
  fi

  local image_name="ghcr.io/${github_user}/opencode-sandbox:latest"
  local auth_config_path="$HOME/.config/opencode-sandbox"
  local history_path="$HOME/.local/share/opencode-sandbox/history"
  
  # Check for updates (background check starts on first load)
  if [[ -f "$auth_config_path/.update-available" ]]; then
    echo "⚠️  A new version of opencode-sandbox is available!"
    echo "   Run: curl -fsSL https://raw.githubusercontent.com/${OPENCODE_SANDBOX_REPO}/main/scripts/opencode_here.sh > /tmp/opencode_here.sh && source /tmp/opencode_here.sh"
    echo ""
    rm -f "$auth_config_path/.update-available"
  fi

  # Detect architecture
  local platform_args=()
  local arch=$(uname -m)
  local os=$(uname -s)

  # On macOS with Apple Silicon, explicitly use ARM64
  if [[ "$os" == "Darwin" && "$arch" == "arm64" ]]; then
    platform_args=(--platform linux/arm64)
    echo "🍎 Detected macOS ARM64 (Apple Silicon)"
  elif [[ "$os" == "Linux" && "$arch" == "aarch64" ]]; then
    platform_args=(--platform linux/arm64)
    echo "🐧 Detected Linux ARM64"
  else
    echo "💻 Using native platform (AMD64)"
  fi

  # Security check: verify gh auth and scope
  if ! command -v gh &>/dev/null; then
    echo "❌ Error: GitHub CLI (gh) not found. Please install it: https://cli.github.com/"
    return 1
  fi

  if ! gh auth status &>/dev/null; then
    echo "❌ Error: Not authenticated with GitHub. Run: gh auth login"
    return 1
  fi

  if ! gh auth status 2>/dev/null | grep -q "Token scopes:"; then
    echo "⚠️  Warning: Could not verify GitHub token scopes"
  fi

  # Pull latest image
  echo "📦 Pulling latest image: $image_name"
  if ! docker pull "$image_name" 2>/dev/null; then
    echo "⚠️  Warning: Could not pull image. Trying to use local image if available..."
    if ! docker image inspect "$image_name" &>/dev/null; then
      echo "❌ Error: Image not found locally or in registry"
      echo "   The GitHub Actions workflow might still be running."
      echo "   Check status at: https://github.com/${github_user}/opencode-sandbox/actions"
      return 1
    fi
  fi

  # Prepare directories
  mkdir -p "$auth_config_path"
  mkdir -p "$history_path"

  # Get GitHub token
  local token=$(gh auth token 2>/dev/null)
  if [[ -z "$token" ]]; then
    echo "❌ Error: Could not get GitHub token"
    return 1
  fi

  echo "🚀 Starting opencode sandbox..."
  echo "   Image: $image_name"
  echo "   Working directory: $(pwd)"
  echo ""

  # Build docker run command (use array for zsh/bash compatibility)
  if [ $# -eq 0 ]; then
    docker run --rm -it \
      "${platform_args[@]}" \
      -v "$(pwd)":/repo \
      -v "$auth_config_path":/home/node/.config/opencode \
      -v "$history_path":/home/node/.local/share/opencode/history \
      -e GITHUB_TOKEN="$token" \
      -e TERM="$TERM" \
      -e COLORTERM="$COLORTERM" \
      -e OPENCODE_HISTORY_DIR=/home/node/.local/share/opencode/history \
      "$image_name"
  else
    docker run --rm -it \
      "${platform_args[@]}" \
      -v "$(pwd)":/repo \
      -v "$auth_config_path":/home/node/.config/opencode \
      -v "$history_path":/home/node/.local/share/opencode/history \
      -e GITHUB_TOKEN="$token" \
      -e TERM="$TERM" \
      -e COLORTERM="$COLORTERM" \
      -e OPENCODE_HISTORY_DIR=/home/node/.local/share/opencode/history \
      "$image_name" opencode "$@"
  fi
}

# Quick alias
alias oh='__opencode_here'

# Check for updates on script load (runs once per day)
__opencode_check_update
