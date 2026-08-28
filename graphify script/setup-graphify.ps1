<#
.SYNOPSIS
    Sets up Graphify (https://github.com/Graphify-Labs/graphify) from scratch on Windows.

.DESCRIPTION
    Mirrors setup-graphify.sh:
      1. Checks for Python 3.10+ and installs it if missing
      2. Checks for the `uv` package manager and installs it if missing (falls back to pipx)
      3. Installs the `graphifyy` PyPI package (CLI command: `graphify`)
      4. Registers Graphify with your AI assistant (Claude Code, etc.)

.PARAMETER Path
    Positional. Pass "." to install project-scoped (same as -Project),
    mirroring `graphify .`'s own convention of using the current directory
    as the project root.

.PARAMETER Project
    Install project-scoped (writes .claude/skills/graphify/... in the current repo)
    instead of the user-level install.

.PARAMETER Extras
    Comma-separated list of optional extras to install, e.g. "pdf,video,neo4j".

.EXAMPLE
    ./setup-graphify.ps1
    ./setup-graphify.ps1 .
    ./setup-graphify.ps1 -Project
    ./setup-graphify.ps1 -Extras "pdf,video,neo4j"
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = "",
    [switch]$Project,
    [string]$Extras = ""
)

# A bare "." (current directory) means "install scoped to this project",
# same as passing -Project.
$ProjectScoped = $Project -or ($Path -eq ".")

$ErrorActionPreference = "Stop"

$MinPyMajor = 3
$MinPyMinor = 10

function Write-Log {
    param([string]$Message)
    Write-Host "[graphify-setup] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[graphify-setup][warn] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[graphify-setup][error] $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-PythonOk {
    param([string]$PyBin)
    if (-not (Test-Command $PyBin)) { return $false }
    try {
        $versionCheck = & $PyBin -c "import sys; sys.exit(0 if sys.version_info >= ($MinPyMajor, $MinPyMinor) else 1)"
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Update-SessionPath {
    # Refresh PATH for this session from both Machine and User scope,
    # plus common install locations that installers may not have registered yet.
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")
    $extra = @(
        "$HOME\.local\bin",
        "$HOME\.cargo\bin",
        "$env:USERPROFILE\.local\bin"
    ) -join ";"
    $env:Path = "$machinePath;$userPath;$extra;$env:Path"
}

Write-Log "Detected OS: Windows (PowerShell $($PSVersionTable.PSVersion))"

# ----------------------------------------------------------------------------
# 1. Check for Python 3.10+, install if missing/outdated
# ----------------------------------------------------------------------------
$PythonBin = $null
foreach ($candidate in @("python", "python3", "py")) {
    if (Test-PythonOk $candidate) {
        $PythonBin = $candidate
        break
    }
}

if ($PythonBin) {
    $verString = (& $PythonBin --version 2>&1)
    Write-Log "Python found ($PythonBin): $verString - satisfies >= $MinPyMajor.$MinPyMinor."
} else {
    Write-Warn "No suitable Python (>= $MinPyMajor.$MinPyMinor) found. Installing..."

    if (Test-Command "winget") {
        winget install --id Python.Python.3.12 -e --source winget
    } else {
        Write-Err "winget not found. Install Python manually: https://www.python.org/downloads/"
        exit 1
    }

    Update-SessionPath

    foreach ($candidate in @("python", "python3", "py")) {
        if (Test-PythonOk $candidate) {
            $PythonBin = $candidate
            break
        }
    }

    if ($PythonBin) {
        $verString = (& $PythonBin --version 2>&1)
        Write-Log "Python installed successfully: $verString"
    } else {
        Write-Err "Python installation failed or version is still < $MinPyMajor.$MinPyMinor."
        Write-Err "Please install manually, open a new terminal, and re-run this script."
        exit 1
    }
}

# ----------------------------------------------------------------------------
# 2. Check for `uv`, install if missing (falls back to pipx)
# ----------------------------------------------------------------------------
$Installer = $null

if (Test-Command "uv") {
    Write-Log "uv found: $(uv --version)"
    $Installer = "uv"
} else {
    Write-Warn "uv not found. Installing uv..."

    if (Test-Command "winget") {
        winget install astral-sh.uv
    } else {
        Write-Warn "winget not found. Falling back to the official install script."
        Invoke-RestMethod -Uri "https://astral.sh/uv/install.ps1" | Invoke-Expression
    }

    Update-SessionPath

    if (Test-Command "uv") {
        Write-Log "uv installed successfully: $(uv --version)"
        $Installer = "uv"
    } else {
        Write-Warn "uv installation could not be verified in this shell session."
        Write-Warn "Falling back to pipx."
        $Installer = "pipx"
    }
}

if ($Installer -eq "pipx" -and -not (Test-Command "pipx")) {
    Write-Warn "pipx not found. Installing via pip..."
    & $PythonBin -m pip install --user pipx
    & $PythonBin -m pipx ensurepath
    Update-SessionPath
}

# ----------------------------------------------------------------------------
# 3. Install graphifyy (CLI command: `graphify`)
# ----------------------------------------------------------------------------
$Package = "graphifyy"
if ($Extras) {
    $Package = "graphifyy[$Extras]"
}

Write-Log "Installing package: $Package (via $Installer)"

if ($Installer -eq "uv") {
    uv tool install $Package
    try { uv tool update-shell } catch { }
} else {
    pipx install $Package
    try { pipx ensurepath } catch { }
}

# ----------------------------------------------------------------------------
# 4. Verify `graphify` CLI is reachable
# ----------------------------------------------------------------------------
Update-SessionPath

if (Test-Command "graphify") {
    $ver = try { graphify --version 2>$null } catch { "installed" }
    Write-Log "graphify CLI installed: $ver"
} else {
    Write-Warn "graphify command not found on PATH in this shell."
    Write-Warn "Try: 'uv tool update-shell' (uv) or 'pipx ensurepath' (pipx), then open a new terminal."
    Write-Warn "Or invoke directly via: python -m graphify"
}

# ----------------------------------------------------------------------------
# 5. Register with AI assistant
# ----------------------------------------------------------------------------
if (Test-Command "graphify") {
    if ($ProjectScoped) {
        Write-Log "Running project-scoped install: graphify install --project"
        graphify install --project
    } else {
        Write-Log "Running user-level install: graphify install"
        graphify install
    }

    Write-Log "Setup complete."
    Write-Log "Next step: open your AI assistant and run: graphify .  (PowerShell) or /graphify . (chat-based assistants)"
} else {
    Write-Warn "Skipping 'graphify install' step because the CLI isn't on PATH yet."
    Write-Warn "Open a new terminal and run: graphify install"
}
