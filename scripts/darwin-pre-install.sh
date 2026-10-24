#!/bin/bash

set -eufo pipefail

echo "📦  Installing dependnecies for packages..."
# Install Homebrew
command -v brew >/dev/null 2>&1 || \
  (echo '🍺  Installing Homebrew' && /bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)")

# Install Nix
# command -v nix >/dev/null 2>&1 || \
#   (echo '📦  Installing Nix' && /bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm --prefer-upstream-nix)")

# Install chezmoi
command -v chezmoi >/dev/null 2>&1 || \
  (echo '📦  Installing chezmoi' && brew install chezmoi)

# Install nupm
echo "Done!"
