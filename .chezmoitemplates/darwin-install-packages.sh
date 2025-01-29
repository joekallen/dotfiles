#!/bin/bash

set -eufo pipefail

echo "🍺  Installing packages with brew..."

brew bundle --no-lock --file=/dev/stdin <<EOF
{{- range .packages.darwin.brews }}
brew {{ . | squote }}
{{- end }}
{{- range .packages.darwin.casks }}
cask {{ . | squote }}
{{- end }}
{{- range .packages.darwin.vscode }}
vscode {{ . | squote }}
{{- end }}
EOF

echo "Done!"
