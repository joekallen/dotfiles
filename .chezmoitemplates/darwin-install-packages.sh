#!/bin/bash

set -eufo pipefail

echo "🍺  Installing packages with brew..."

{{- $extra := "packages-personal" }}
{{- if .chezmoi.config.data.isWorkMachine }}
  {{- $extra = "packages-work" }}
{{- end }}
brew bundle --no-lock --file=/dev/stdin <<EOF
{{- range concat (dig "packages" "darwin" "brews" (list) .) (dig $extra "darwin" "brews" (list) .) }}
brew {{ . | squote }}
{{- end }}
{{- range concat (dig "packages" "darwin" "casks" (list) .) (dig $extra "darwin" "casks" (list) .) }}
cask {{ . | squote }}
{{- end }}
{{- range concat (dig "packages" "darwin" "vscode" (list) .) (dig $extra "darwin" "vscode" (list) .) }}
vscode {{ . | squote }}
{{- end }}
EOF
