#!/bin/bash

# opencode_here - Helper function to run opencode in Docker sandbox
# Usage: source this file, then run 'opencode_here' or 'oh' alias

# Configuration - the Docker image is always hosted at fabianlema
SANDBOX_REGISTRY_USER="fabianlema"
SANDBOX_IMAGE_NAME="opencode-sandbox"

function __opencode_here() {
  local image_name="ghcr.io/${SANDBOX_REGISTRY_USER}/${SANDBOX_IMAGE_NAME}:latest"
  local auth_config_path="$HOME/.config/opencode-sandbox"
  local history_path="$HOME/.local/share/opencode-sandbox/history"

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
      echo "   Check status at: https://github.com/${SANDBOX_REGISTRY_USER}/${SANDBOX_IMAGE_NAME}/actions"
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
