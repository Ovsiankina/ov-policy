# Contract: preset `ov-policy` and bundle `ov`

## `presets/ov-policy/preset.yml`

| Key | Value |
|-----|-------|
| `schema_version` | `"1.0"` |
| `preset.id` | `ov-policy` |
| `requires.speckit_version` | `">=1.2.0"` |
| `provides.templates[0]` | `{type: template, name: constitution-template, file: templates/ov-policy.md, strategy: prepend, description: "Prepend POLICY.md to the constitution template"}` |

- `templates/ov-policy.md` is byte-identical to the ov repo's `POLICY.md`, written only by
  `scripts/ov-sync-policy.sh` (R-10). Its first line is `<!-- ov-policy -->`.
- **Check**: after `specify preset add --dev <repo>/presets/ov-policy`,
  `.specify/scripts/bash/resolve-template.sh constitution-template --json` returns
  `TEMPLATE_CONTENT` that starts with the contents of `ov-policy.md`, followed by the core
  template (Scenario 7.1).

## ov repo CI: `.github/workflows/ov-ci.yml`

- `scripts/ov-sync-policy.sh --check` fails if `POLICY.md` is missing its marker line or
  differs from `presets/ov-policy/templates/ov-policy.md`. Until the author writes POLICY.md,
  the check reports "POLICY.md not written yet" and the copy contains only the marker line.

## `bundles/ov/bundle.yml`

| Key | Value |
|-----|-------|
| `schema_version` | `"1.0"` |
| `bundle.id` / `name` / `version` / `role` / `description` / `author` / `license` | `ov`, …; author/license left `TODO(author)` |
| `requires.speckit_version` | `">=1.2.0"` |
| `integration.id` | `claude` |
| `provides.extensions` | `[{id: ov, version: "0.1.0"}]` |
| `provides.presets` | `[{id: ov-policy, version: "0.1.0", priority: 10, strategy: prepend}]` |

As built against spec-kit 1.2.0 (T065): the bundle parser reads components only under
`provides:`, requires a `version` pin on each and an integer `priority` on presets, and reads
`source:` as a catalog name, not a path. Local sources are therefore rejected (the R-11
risk), and `source:` is left out until ov is published in a catalog.

- **Check**: `specify bundle validate --path <dir>/bundle.yml` exits 0. In 1.2.0 the manifest is
  a `--path` option, not an argument, and references resolve against the spec-kit project that
  contains the manifest (else the cwd). So the check needs a copy of `bundle.yml` inside a
  project where the extension and the preset are installed; run on `bundles/ov/bundle.yml` it
  checks this repo, where the preset is not installed, and exits 1 online (`--offline`: 0 with
  a warning). If local `source:` values are rejected (research R-11 risk), the bundle is
  published with release-URL sources, and the quickstart installs the extension and preset
  separately for dev.
