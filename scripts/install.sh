#!/bin/bash

set -eufo pipefail

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/joekallen/dotfiles/refs/heads/main/scripts/darwin-preinstall.sh)"

chezmoi init --apply joekallen
