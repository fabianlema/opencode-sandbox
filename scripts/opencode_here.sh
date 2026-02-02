#!/bin/bash

# opencode_here - Helper function to run opencode in Docker sandbox
# Usage: source this file, then run 'opencode_here' or 'oh' alias

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

  # Detect architecture
  local platform_flag=""
  local arch=$(uname -m)
  local os=$(uname -s)

  # On macOS with Apple Silicon, explicitly use ARM64
  if [[ "$os" == "Darwin" && "$arch" == "arm64" ]]; then
    platform_flag="--platform linux/arm64"
    echo "🍎 Detected macOS ARM64 (Apple Silicon)"
  elif [[ "$os" == "Linux" && "$arch" == "aarch64" ]]; then
    platform_flag="--platform linux/arm64"
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

  # Prepare auth config directory
  mkdir -p "$auth_config_path"

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

  # Build docker run command (platform_flag must be unquoted to expand properly)
  if [ $# -eq 0 ]; then
    docker run --rm -it \
      $platform_flag \
      -v "$(pwd)":/repo \
      -v "$auth_config_path":/home/node/.config/opencode \
      -e GITHUB_TOKEN="$token" \
      -e TERM="$TERM" \
      -e COLORTERM="$COLORTERM" \
      "$image_name"
  else
    docker run --rm -it \
      $platform_flag \
      -v "$(pwd)":/repo \
      -v "$auth_config_path":/home/node/.config/opencode \
      -e GITHUB_TOKEN="$token" \
      -e TERM="$TERM" \
      -e COLORTERM="$COLORTERM" \
      "$image_name" opencode "$@"
  fi
}

# Quick alias
alias oh='__opencode_here'
