#!/bin/sh

set -eufo pipefail

echo "📦  Installing dependnecies for packages..."
# Install Homebrew
command -v brew >/dev/null 2>&1 || \
  (echo '🍺  Installing Homebrew' && /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)")

echo "Done!"
