# Dotfiles

## Setup

These dotfiles are managed with [chezmoi](https://github.com/twpayne/chezmoi).

Run the following command, which grabs and runs the setup script. The setup script is
part of the chezmoi configuration, but this executes part of itself as a bootstrap.

```sh
echo '📦  Installing dotfiles' && /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/joekallen/dotfiles/refs/heads/main/scripts/install.sh)"

```

## Navigating

All software to install is done through brew, mise and external packages. The structure is descibed [here](#format) and configuration locations are listed [here](#locations)

below, but

### Locations

### Format

Ideally work and personal packages contain only distinct differences. This is done to avoid having to remember to add/remove a package in multiple places.

<!-- add a schema? -->
```yaml
# type will likely be (packages, mise, nupm). packages is used for brew
type:

```
