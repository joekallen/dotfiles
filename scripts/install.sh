#!/bin/bash

set -eufo pipefail

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/joekallen/dotfiles/refs/heads/main/scripts/darwin-pre-install.sh)"

chezmoi init --apply joekallen
