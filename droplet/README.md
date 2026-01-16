# Ralph Droplet Environment

This directory contains the setup scripts and documentation for running Ralph in a long-running droplet environment.

## Overview

Ralph runs in a dedicated droplet to limit the blast radius when using Claude in dangerous mode (`--dangerously-skip-permissions`). This isolation ensures that even in the worst-case scenario (e.g., prompt injection leading to code exfiltration), the impact is contained to the droplet environment.

## Architecture

- **Droplet**: Ubuntu Linux server running Ralph continuously
- **Nginx**: Reverse proxy on port 80 (Cloudflare handles TLS termination)
- **Systemd**: Service manager for running Ralph as a long-running process
- **User isolation**: Ralph runs as a non-root user with proper environment setup

## Setup Process

### 1. Root Installation

Run as root to install system-level dependencies:

```bash
sudo ./install-root.sh
```

This installs:
- Nginx (with proxy configuration for port 80)
- systemd (if not pre-installed)
- jq
- git
- GitHub CLI (gh)

**Note**: NVM, Node.js, and Bun are installed by the user script (requires user context).

### 2. User Installation

Switch to the non-root user and run:

```bash
cd ~/prompts/droplet
./install-user.sh
```

This:
- Installs NVM and Node.js (via NVM)
- Installs Bun
- Clones/sets up the Ralph repository (will prompt for git URL)
- Configures the systemd service
- Creates a wrapper script that sources bashrc before running Ralph
- Enables the service (optionally starts it)

**Note**: You'll need to have git/gh credentials configured before running the user installation script.

## Systemd Service

The Ralph loop runs as a systemd user service. The service uses a wrapper script (`ralph-wrapper.sh`) that sources the user's bashrc before executing the loop, ensuring all environment variables, paths, and tool configurations are properly loaded.

## Security Considerations

- Ralph runs in dangerous mode but is isolated in a droplet
- Worst-case scenario: code exfiltration (acceptable risk)
- No access to production systems or sensitive credentials
- Cloudflare provides TLS termination and additional security layers

## Maintenance

- Service logs: `journalctl --user -u ralph-loop.service`
- Service status: `systemctl --user status ralph-loop.service`
- Restart service: `systemctl --user restart ralph-loop.service`

### Enabling Service to Run Without User Login

By default, systemd user services only run when the user is logged in. To enable the service to run in the background without an active login session:

```bash
loginctl enable-linger $(whoami)
```

This allows the Ralph loop to continue running even after you disconnect from the droplet.
