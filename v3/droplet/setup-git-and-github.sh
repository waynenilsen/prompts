#!/usr/bin/env bash
#
# setup-git-and-github.sh - Sets up Git with SSH checkout and commit signing
#
# Configures:
# - Single SSH key for both GitHub authentication and commit signing
# - Global git configuration
#
# Must be run as a non-root user
#

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "Error: This script must NOT be run as root"
    exit 1
fi

echo "Setting up Git and GitHub SSH authentication + commit signing..."
echo ""

# Check Git version (SSH commit signing requires Git 2.34+)
GIT_VERSION=$(git --version | awk '{print $3}')
REQUIRED_VERSION="2.34.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$GIT_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Warning: Git version $GIT_VERSION detected. SSH commit signing requires Git 2.34+"
    echo "Consider updating Git if commit signing doesn't work."
    echo ""
fi

# Prompt for user information if not set
if [ -z "${GITHUB_EMAIL:-}" ]; then
    read -p "Enter your GitHub email: " GITHUB_EMAIL
fi

if [ -z "${GITHUB_NAME:-}" ]; then
    read -p "Enter your name for Git commits: " GITHUB_NAME
fi

# Set up SSH directory
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# SSH key path (single key for both authentication and signing)
SSH_KEY_FILE="$SSH_DIR/id_ed25519_github"

# Generate SSH key (if doesn't exist)
if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "Generating SSH key for authentication and commit signing..."
    ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$SSH_KEY_FILE" -N ""
    echo "✓ SSH key generated"
else
    echo "✓ SSH key already exists: $SSH_KEY_FILE"
fi

# Start ssh-agent and add key
echo ""
echo "Configuring ssh-agent..."
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    eval "$(ssh-agent -s)" > /dev/null
fi

# Add key to ssh-agent
ssh-add "$SSH_KEY_FILE" 2>/dev/null || true

# Configure SSH config for GitHub
SSH_CONFIG="$SSH_DIR/config"
if [ ! -f "$SSH_CONFIG" ] || ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
    echo "" >> "$SSH_CONFIG"
    echo "Host github.com" >> "$SSH_CONFIG"
    echo "  User git" >> "$SSH_CONFIG"
    echo "  IdentityFile $SSH_KEY_FILE" >> "$SSH_CONFIG"
    echo "  AddKeysToAgent yes" >> "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    echo "✓ SSH config updated"
fi

# Configure global Git settings
echo ""
echo "Configuring global Git settings..."
git config --global user.name "$GITHUB_NAME"
git config --global user.email "$GITHUB_EMAIL"

# Configure SSH commit signing (using the same key)
git config --global gpg.format ssh
git config --global user.signingkey "$SSH_KEY_FILE.pub"
git config --global commit.gpgsign true
git config --global tag.gpgsign true

echo "✓ Git configured for SSH checkout and commit signing"
echo ""

# Read public key
SSH_PUB_KEY=$(cat "$SSH_KEY_FILE.pub")

# Output instructions
cat <<EOF

═══════════════════════════════════════════════════════════════════════════════
  ACTION REQUIRED: Add this key to your GitHub account (twice)
═══════════════════════════════════════════════════════════════════════════════

You need to add the SAME public key twice to GitHub - once as an Authentication
Key and once as a Signing Key.

Public Key (use this same key for both):
   ───────────────────────────────────────────────────────────────────────────
$SSH_PUB_KEY
   ───────────────────────────────────────────────────────────────────────────

1. AUTHENTICATION KEY (for git clone/push via SSH)
   ───────────────────────────────────────────────────────────────────────────
   
   Go to: https://github.com/settings/keys
   Click: "New SSH key"
   
   Title: droplet-authentication-$(whoami)
   Key type: Authentication Key
   Paste the public key above

2. SIGNING KEY (for commit signature verification)
   ───────────────────────────────────────────────────────────────────────────
   
   Go to: https://github.com/settings/keys
   Click: "New SSH key"
   
   Title: droplet-signing-$(whoami)
   Key type: Signing Key  ⚠️  IMPORTANT: Select "Signing Key" not "Authentication Key"
   Paste the SAME public key above

After adding the key twice (once as Authentication, once as Signing), test the setup:
  git clone git@github.com:yourusername/yourrepo.git
  cd yourrepo
  echo "test" > test.txt
  git add test.txt
  git commit -m "test commit"
  git push

Your commits should show as "Verified" on GitHub.

═══════════════════════════════════════════════════════════════════════════════

EOF

echo "✓ Setup complete!"
echo ""
echo "References:"
echo "  - GitHub SSH keys: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
echo "  - SSH commit signing: https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification"
