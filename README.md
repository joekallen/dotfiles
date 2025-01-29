# Dotfiles

## Setup

These dotfiles are managed with [chezmoi](https://github.com/twpayne/chezmoi).

Run the following command, which grabs and runs the setup script. The setup script is
part of the chezmoi configuration, but this executes part of itself as a bootstrap.

```sh
echo '📦  Installing dotfiles' && /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/joekallen/dotfiles/HEAD/scripts/install.sh)"
```
