# Opencode Sandbox

Docker sandbox environment for running [opencode](https://opencode.ai) AI agents with all necessary tools pre-installed.

## Features

- **Multi-architecture**: Supports both AMD64 and ARM64 (Apple Silicon)
- **Pre-installed tools**: git, gh, python3, jq, node, and more
- **Secure**: Runs as non-root user (`node`)
- **GHCR hosted**: Published to GitHub Container Registry

> **Note**: Daily automated builds were removed since Docker Desktop now natively supports creating OpenCode sandboxes.

## Quick Start

### 1. Install the helper function

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
source /path/to/opencode-sandbox/scripts/opencode_here.sh
```

Or use the alias directly:

```bash
# Clone the repo and source it
git clone https://github.com/fabianlema/opencode-sandbox.git
cd opencode-sandbox
source scripts/opencode_here.sh

# Now you can use the alias anywhere
oh
```

### 2. Use in any project

Navigate to any project directory and run:

```bash
oh                    # Start opencode interactive mode
oh --help             # Show opencode help
oh "review this code" # Pass arguments directly
```

## Manual Usage (without script)

```bash
docker run --rm -it \
  -v "$(pwd)":/repo \
  -e GITHUB_TOKEN="$(gh auth token)" \
  ghcr.io/fabianlema/opencode-sandbox:latest
```

## Requirements

- Docker installed and running
- GitHub CLI (`gh`) authenticated
- GitHub token with `repo` scope (for push operations)

## Architecture Detection

The script automatically detects your platform:
- **macOS + Apple Silicon** → Uses `linux/arm64`
- **Linux ARM64** → Uses `linux/arm64`
- **Others** → Uses native platform (AMD64)

## Configuration

The script stores opencode configuration in:
```
~/.config/opencode-sandbox/
```

This persists authentication and settings between runs.

## Building Locally

```bash
docker build -t opencode-sandbox:local .
```

## License

MIT
