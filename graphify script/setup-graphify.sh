#!/usr/bin/env bash
#
# setup-graphify.sh
#
# Sets up Graphify (https://github.com/Graphify-Labs/graphify) from scratch:
#   1. Detects the OS
#   2. Checks for Python 3.10+ and installs it if missing
#   3. Checks for the `uv` package manager and installs it if missing
#   4. Installs the `graphifyy` PyPI package (CLI command: `graphify`)
#   5. Registers Graphify with your AI assistant (Claude Code, etc.)
#
# Usage:
#   chmod +x setup-graphify.sh
#   ./setup-graphify.sh                # user-level install
#   ./setup-graphify.sh .              # project-scoped install (current repo)
#   ./setup-graphify.sh --project      # project-scoped install (current repo)
#   ./setup-graphify.sh --with-extras "pdf,video,neo4j"   # install optional extras
#
set -euo pipefail

# ----------------------------------------------------------------------------
# Config / args
# ----------------------------------------------------------------------------
PROJECT_SCOPED=false
EXTRAS=""
MIN_PY_MAJOR=3
MIN_PY_MINOR=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    .)
      # A bare "." (current directory) means "install scoped to this project",
      # same as passing --project.
      PROJECT_SCOPED=true
      shift
      ;;
    --project)
      PROJECT_SCOPED=true
      shift
      ;;
    --with-extras)
      EXTRAS="${2:-}"
      shift 2
      ;;
    --with-extras=*)
      EXTRAS="${1#*=}"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

log()   { printf '\033[1;34m[graphify-setup]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[graphify-setup][warn]\033[0m %s\n' "$1"; }
error() { printf '\033[1;31m[graphify-setup][error]\033[0m %s\n' "$1" >&2; }

# ----------------------------------------------------------------------------
# 1. Detect OS
# ----------------------------------------------------------------------------
OS="unknown"
case "$(uname -s)" in
  Darwin*) OS="macos" ;;
  Linux*)
    if [[ -f /etc/debian_version ]]; then
      OS="debian"
    else
      OS="linux"
    fi
    ;;
  CYGWIN*|MINGW*|MSYS*) OS="windows" ;;
esac
log "Detected OS: $OS"

# ----------------------------------------------------------------------------
# 2. Check for Python 3.10+, install if missing/outdated
# ----------------------------------------------------------------------------
python_ok() {
  local py_bin="$1"
  command -v "$py_bin" >/dev/null 2>&1 || return 1
  "$py_bin" - <<'EOF'
import sys
sys.exit(0 if sys.version_info >= (3, 10) else 1)
EOF
}

PYTHON_BIN=""
for candidate in python3 python; do
  if python_ok "$candidate"; then
    PYTHON_BIN="$candidate"
    break
  fi
done

if [[ -n "$PYTHON_BIN" ]]; then
  log "Python $($PYTHON_BIN --version 2>&1 | awk '{print $2}') found ($PYTHON_BIN) — satisfies >= ${MIN_PY_MAJOR}.${MIN_PY_MINOR}."
else
  warn "No suitable Python (>= ${MIN_PY_MAJOR}.${MIN_PY_MINOR}) found. Installing..."
  case "$OS" in
    macos)
      if ! command -v brew >/dev/null 2>&1; then
        error "Homebrew not found. Install it first: https://brew.sh"
        exit 1
      fi
      brew install python
      # Make sure the Homebrew-linked python3 is on PATH for this session
      # (Apple Silicon: /opt/homebrew/bin, Intel: /usr/local/bin)
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
      PYTHON_BIN="python3"
      ;;
    debian)
      sudo apt update
      sudo apt install -y python3.12 python3-pip pipx
      PYTHON_BIN="python3"
      ;;
    linux)
      warn "Non-Debian Linux detected. Attempting a best-effort install via package manager."
      if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3.12
      elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y python3.12
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm python
      else
        error "Could not detect a supported package manager. Install Python >= 3.10 manually: https://www.python.org/downloads/"
        exit 1
      fi
      PYTHON_BIN="python3"
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        winget install --id Python.Python.3.12 -e
      else
        error "winget not found. Install Python manually: https://www.python.org/downloads/"
        exit 1
      fi
      PYTHON_BIN="python3"
      ;;
    *)
      error "Unsupported OS for automatic Python install. Install Python >= 3.10 manually: https://www.python.org/downloads/"
      exit 1
      ;;
  esac

  if python_ok "$PYTHON_BIN"; then
    log "Python installed successfully: $($PYTHON_BIN --version 2>&1)"
  else
    error "Python installation failed or version is still < ${MIN_PY_MAJOR}.${MIN_PY_MINOR}. Please install manually and re-run this script."
    exit 1
  fi
fi

# ----------------------------------------------------------------------------
# 3. Check for `uv`, install if missing (falls back to pipx)
# ----------------------------------------------------------------------------
INSTALLER=""

if command -v uv >/dev/null 2>&1; then
  log "uv found: $(uv --version)"
  INSTALLER="uv"
else
  warn "uv not found. Installing uv..."
  case "$OS" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        brew install uv
      else
        curl -LsSf https://astral.sh/uv/install.sh | sh
      fi
      ;;
    debian|linux)
      curl -LsSf https://astral.sh/uv/install.sh | sh
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        winget install astral-sh.uv
      else
        curl -LsSf https://astral.sh/uv/install.sh | sh
      fi
      ;;
    *)
      curl -LsSf https://astral.sh/uv/install.sh | sh
      ;;
  esac

  # uv installs to ~/.local/bin or ~/.cargo/bin depending on version; add to PATH for this session
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

  if command -v uv >/dev/null 2>&1; then
    log "uv installed successfully: $(uv --version)"
    INSTALLER="uv"
  else
    warn "uv installation could not be verified in this shell session."
    warn "Falling back to pipx."
    INSTALLER="pipx"
  fi
fi

if [[ "$INSTALLER" == "pipx" ]] && ! command -v pipx >/dev/null 2>&1; then
  warn "pipx not found. Installing via pip..."
  "$PYTHON_BIN" -m pip install --user pipx
  "$PYTHON_BIN" -m pipx ensurepath
  export PATH="$HOME/.local/bin:$PATH"
fi

# ----------------------------------------------------------------------------
# 4. Install graphifyy (CLI command: `graphify`)
# ----------------------------------------------------------------------------
PACKAGE="graphifyy"
if [[ -n "$EXTRAS" ]]; then
  PACKAGE="graphifyy[${EXTRAS}]"
fi

log "Installing package: $PACKAGE (via $INSTALLER)"

if [[ "$INSTALLER" == "uv" ]]; then
  uv tool install "$PACKAGE"
  # Ensure the uv tool bin dir is on PATH for future shells
  uv tool update-shell || true
else
  pipx install "$PACKAGE"
  pipx ensurepath || true
fi

# ----------------------------------------------------------------------------
# 5. Verify `graphify` CLI is reachable
# ----------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

if command -v graphify >/dev/null 2>&1; then
  log "graphify CLI installed: $(graphify --version 2>/dev/null || echo 'installed')"
else
  warn "graphify command not found on PATH in this shell."
  warn "Try: 'uv tool update-shell' (uv) or 'pipx ensurepath' (pipx), then open a new terminal."
  warn "Or invoke directly via: python -m graphify"
fi

# ----------------------------------------------------------------------------
# 6. Register with AI assistant
# ----------------------------------------------------------------------------
if command -v graphify >/dev/null 2>&1; then
  if [[ "$PROJECT_SCOPED" == "true" ]]; then
    log "Running project-scoped install: graphify install --project"
    graphify install --project
  else
    log "Running user-level install: graphify install"
    graphify install
  fi

  log "Setup complete."
  log "Next step: open your AI assistant and run: /graphify .  (or 'graphify .' in PowerShell)"
else
  warn "Skipping 'graphify install' step because the CLI isn't on PATH yet."
  warn "Open a new terminal and run: graphify install"
fi
