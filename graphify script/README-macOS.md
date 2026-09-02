# Graphify Setup on macOS

This guide explains how to install and run Graphify on macOS with
`setup-graphify.sh`.

## Requirements

- macOS
- An internet connection
- Python 3.10 or newer

The setup script installs Python 3.12 through Homebrew when a suitable Python
version is not already available.

## Install Homebrew

Skip this section if `brew --version` already works. In Terminal, run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow Homebrew's printed instructions to add `brew` to your `PATH`, then close
and reopen Terminal.

## Run the Setup Script

In Terminal, change to the directory containing the script:

```bash
cd "/path/to/agent dev org/.github/graphify script"
```

Make the script executable and run a user-level installation:

```bash
chmod +x setup-graphify.sh
./setup-graphify.sh
```

For a project-scoped installation, change to the project root and invoke the
script by its full path:

```bash
cd "/path/to/your/project"
"/path/to/agent dev org/.github/graphify script/setup-graphify.sh" --project
```

Passing `.` instead of `--project` also creates a project-scoped installation:

```bash
"/path/to/agent dev org/.github/graphify script/setup-graphify.sh" .
```

Install optional Graphify features with a comma-separated list:

```bash
./setup-graphify.sh --with-extras "pdf,video,neo4j"
```

## Verify Graphify

Close and reopen Terminal, then run:

```bash
graphify --version
```

If `graphify` is not found, update the shell configuration and reopen Terminal:

```bash
uv tool update-shell
```

If the installer used `pipx` instead of `uv`, run:

```bash
pipx ensurepath
```

To process the current project, change to its root and run:

```bash
graphify .
```