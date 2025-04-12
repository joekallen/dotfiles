#!/bin/bash

set -eufo pipefail

echo "📦  Installing dependnecies for packages..."
# Install Homebrew
command -v brew >/dev/null 2>&1 || \
  (echo '🍺  Installing Homebrew' && /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)")

# Install chezmoi
command -v chezmoi >/dev/null 2>&1 || \
  (echo '📦  Installing chezmoi' && brew install chezmoi)

# Install nushell
command -v nu >/dev/null 2>&1 || \
  (echo '📦  Installing nushell' && brew install nushell)

# Install nupm
echo "Done!"
