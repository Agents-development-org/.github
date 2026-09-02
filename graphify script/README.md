# Graphify Setup on Windows

This guide explains how to install Python and run `setup-graphify.ps1` in Windows PowerShell.

## Requirements

- Windows 10 or Windows 11
- PowerShell
- Internet access
- Python 3.10 or newer

The setup script can install Python automatically with `winget` if a suitable version is not already installed.

## Install Python Manually

Skip this section if you want the setup script to install Python automatically.

### Option 1: Install with winget

Open PowerShell and run:

```powershell
winget install --id Python.Python.3.12 -e --source winget
```

Close and reopen PowerShell, then verify the installation:

```powershell
python --version
```

The displayed version should be Python 3.10 or newer.

### Option 2: Install from python.org

1. Open <https://www.python.org/downloads/windows/>.
2. Download the latest Python 3 installer for Windows.
3. Run the installer.
4. Select **Add Python to PATH** before choosing **Install Now**.
5. Close and reopen PowerShell.
6. Run `python --version` to verify the installation.

If `python` is not recognized, try:

```powershell
py --version
```

## Run the Setup Script

Open PowerShell and change to the directory containing the script:

```powershell
cd "D:\Projects\Agent dev work space\agent dev org\.github\graphify script"
```

If PowerShell blocks local scripts, allow them for the current terminal session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Run a user-level installation:

```powershell
.\setup-graphify.ps1
```

Or install Graphify only for the current project. First change to the project directory, then run the script by its full path:

```powershell
& "D:\Projects\Agent dev work space\agent dev org\.github\graphify script\setup-graphify.ps1" -Project
```

You can also install optional Graphify features:

```powershell
.\setup-graphify.ps1 -Extras "pdf,video,neo4j"
```

## Verify Graphify

Close and reopen PowerShell, then run:

```powershell
graphify --version
```

If the command is not found, run:

```powershell
uv tool update-shell
```

Close and reopen PowerShell again. If the script used `pipx` instead of `uv`, run `pipx ensurepath` instead.

After installation, process the current project with:

```powershell
graphify .
```