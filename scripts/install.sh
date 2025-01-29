#!/bin/bash

set -eufo pipefail

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/joekallen/dotfiles/refs/heads/main/.chezmoitemplates/darwin-install-package-managers.sh)"

chezmoi init --apply joekallen
