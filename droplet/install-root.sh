#!/usr/bin/env bash
#
# install-root.sh - Root installation script for Ralph droplet
#
# Installs system-level dependencies required for running Ralph
# Must be run as root
#

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Installing system dependencies for Ralph droplet..."

# Update package list
apt-get update

# Install base dependencies
apt-get install -y \
    curl \
    wget \
    git \
    jq \
    build-essential \
    nginx \
    unzip

# Install GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update
    apt-get install -y gh
fi

# Install NVM (Node Version Manager) - for the user, not root
# NVM should be installed as the user, but we'll create the directory structure
echo "NVM will be installed by the user script (requires user context)"

# Install Bun - for the user, not root
# Bun installs to $HOME/.bun, so it should be installed by the user script
echo "Bun will be installed by the user script (requires user context)"

# Verify systemd is available (should be pre-installed on Ubuntu)
if ! command -v systemctl &> /dev/null; then
    echo "Warning: systemd not found. Installing systemd..."
    apt-get install -y systemd
fi

# Configure Nginx proxy
echo "Configuring Nginx proxy..."
cat > /etc/nginx/sites-available/ralph-proxy <<'EOF'
server {
    listen 80;
    server_name _;

    # Proxy configuration for future use
    # Currently just a placeholder for Cloudflare TLS termination
    location / {
        return 200 "Ralph proxy is running";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/ralph-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Start and enable Nginx
systemctl enable nginx
systemctl restart nginx

echo ""
echo "✓ Root installation complete!"
echo ""
echo "Next steps:"
echo "  1. Switch to your user account"
echo "  2. Run: ./install-user.sh"
echo ""
