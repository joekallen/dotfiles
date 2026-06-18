---
name: mr-review-helm
description: >
  Language-specific review checklist for Helm chart diffs. Used by
  gitlab-mr-review to analyze Helm/YAML changes with Helm-specific criteria.
  Triggers when gitlab-mr-review detects Helm or YAML as the primary language.
---
# Helm MR Review Checklist

This skill is loaded by `gitlab-mr-review` when the diff is primarily Helm/YAML.
It replaces the general checklist in step 6c. Follow steps 6d–6f from
`gitlab-mr-review` unchanged.

---

## Checklist

For every changed file, evaluate ALL of the following and record a finding for
each issue found.

### Template correctness
- `define` name follows the `<chart-name>.<helper-name>` convention
- `include` used instead of `template` wherever the result is piped
- All `.Values.*` and `dig` references have safe defaults (e.g. `| default ""`,
  `| default (dict)`)
- `fromYaml` results guarded with `| default (dict)` to prevent nil map panics
- `tpl` calls pass a valid non-nil context
- `fail` messages are descriptive and include the offending value
- Names and labels piped through `| trunc 63 | trimSuffix "-"` where required
  by Kubernetes limits
- `compact | join "-"` pipelines produce valid DNS-label-safe output

### Helper template contracts
- New helpers follow the `(list $ .Values)` parameter convention used by
  existing helpers
- Helpers that accept a list correctly index with `index . 0`, `index . 1`, etc.
- Private helpers (prefixed `_`) are not called directly from outside the library

### Kubernetes / label correctness
- Label values comply with `^[a-z0-9A-Z]([a-z0-9A-Z\-_.]*[a-z0-9A-Z])?$`
  format and are ≤63 characters
- Annotation keys comply with `(prefix/)?name` format (prefix ≤253, name ≤63)
- ArgoCD sync-wave values are quoted strings, not bare integers

### JSON schema files
- `$id` matches the file's logical path
- `patternProperties` regex is valid JSON Schema syntax
- `type` and `description` present on all properties

### Documentation
- Every new `define` block has a `{{- /* ... */ -}}` doc comment
- Doc comment includes: purpose, parameters, and a usage example

### Breaking changes
- Renamed or removed `define` names are flagged as breaking (consumers use
  `include "common-util.X"`)
- Changed parameter conventions (e.g. switching from single arg to list) are
  flagged as breaking