# Research: ov spec-kit extension, preset and bundle

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-15

Sources: the installed `specify` 1.2.0 package
(`~/.local/share/uv/tools/specify-cli/lib/python3.12/site-packages/specify_cli/`), its bundled
`git` and `bug` extensions under `core_pack/extensions/`, the spec-kit reference pages, and the
Claude Code docs (hooks, settings, skills, GitHub Actions). File/line references point into
that package.

## Author decisions (resolved 2026-10-15)

### D-1: `/ov-*` command names cannot come from spec-kit → **accept `/speckit-ov-*`**

- **Finding**: For skills-mode integrations (Claude), `CommandRegistrar._compute_output_name`
  (`agents.py:581`) always produces `speckit-<name>` with dots turned into hyphens. The skill
  frontmatter `name` is then overwritten with that value (`agents.py:485`). Aliases go
  through the same function, and in skills mode only the primary command's skill is rendered
  (`extensions/__init__.py:4182-4195`). So `speckit.ov.help` lands as
  `.claude/skills/speckit-ov-help/SKILL.md` and is invoked as `/speckit-ov-help`. An alias
  `ov-help` would also normalize to `speckit-ov-help`. There is no manifest field that changes
  this.
- **Decision (author)**: accept `/speckit-ov-<cmd>`. Constitution amended to 1.2.0
  (Principle I exception 1 covers command names imposed by spec-kit); spec FR-001, FR-005 and
  SC-002 updated.
- **Rejected**: `/ov-*` wrapper skills written by init (they exist only after init, every
  command shows twice, and spec-kit doesn't track them); a Claude Code plugin (namespaced
  `/ov:help`, a second distribution channel).

### D-2: Who installs the `.aiignore` PreToolUse hook → **spec-kit agent event**

- **Finding**: spec-kit 1.2.0 supports extension-declared **agent events**. In
  `extension.yml`, `events: pre_tool_use: {command, matcher, timeout}` (validated in
  `events/__init__.py:1904`) is rendered into `.claude/settings.json` as a `PreToolUse` hook
  on every `extension add`/`enable` (`extensions/command_add.py:293`). It is merged without
  clobbering other entries, tagged `__speckit_event__`, and removed on `extension remove`.
  The hook runs spec-kit's generated dispatcher `.specify/events.py`. That dispatcher pipes the
  hook's stdin to the command template's `scripts.sh` script and passes its exit code and
  stderr straight back (`events/__init__.py:289-326`), so the script's `exit 2` reaches Claude
  Code as a deny.
- **Decision (author)**: A. Spec FR-032/FR-033 reworded.
- **Options considered**: (A) declare the hook as a spec-kit event: it is installed at `extension add`,
  `/ov-nogo` verifies it instead of installing it, and the spec text of FR-032 changes.
  (B) `/ov-nogo` merges the hook into `.claude/settings.json` itself with a bash + `jq`
  script, matching FR-032 literally. Recommendation: **A**. spec-kit then handles
  merge, idempotency and uninstall (FR-033 for free), and the hook is fail-open until
  `.aiignore` exists (spec edge case 1). Cost: an internal command `speckit.ov.guard` whose
  only job is to carry the `scripts.sh` entry. It is visible as a skill and documented as
  internal. The dispatcher is Python, but it is spec-kit's file, not ov's, so it does not
  break the "no Python package" constraint.

## Resolved decisions

### R-1: Repository layout mirrors spec-kit's bundled extensions

- **Decision**: `extensions/ov/` (`extension.yml`, `commands/`, `scripts/bash/`,
  `templates/`, `ov-config-template.yml`), `presets/ov-policy/`, `bundles/ov/`.
- **Rationale**: same shape as `core_pack/extensions/git/` (manifest, `commands/speckit.git.*.md`,
  `scripts/bash/*.sh`, config template). The final path component is `ov` because
  `specify extension add <path> --dev` takes a directory path. The acceptance command is read
  as `cd scratch && specify extension add <repo>/extensions/ov --dev`: the literal
  `specify init scratch && specify extension add ov --dev` would run outside the project.
- **Alternatives**: extension at the repo root. Rejected: it would ship this repo's
  `README.md`, `POLICY.md`, `specs/` and `.specify/` into every target project.
- **Note**: unlike `git`/`bug`, `extensions/ov/` gets **no README.md**. Principle VI makes
  the author the only writer of the extension's documentation. A `.extensionignore`
  (supported, `extensions/__init__.py:1257`) keeps tests and fixtures out of the installed copy.

### R-2: Install copies the whole extension directory; nothing runs at install

- **Decision**: templates for project files ship under `.specify/extensions/ov/templates/`
  (FR-006, Q3-C) and are copied by the owning command's script. No post-install step.
- **Rationale**: `extension add` does a `copytree` of the source dir
  (`extensions/__init__.py:3035`), restores exec bits on shipped scripts (`:3251`), and
  registers `hooks:` in `.specify/extensions.yml` (`:5866`). There is no post-install script
  mechanism.
- **Consequence**: `.specify/extensions/ov/` is **committed** in target projects
  (`.specify/.gitignore` ignores only `feature.json`, `extensions/*/local-config.yml` and
  integration packages), so CI can reach the shipped scripts. See R-6 for why CI uses the
  base-branch copy.

### R-3: Command templates follow the `git`/`bug` format

- **Decision**: `commands/speckit.ov.<cmd>.md` with `description:` frontmatter, a
  `## User Input` block with `$ARGUMENTS`, and an `## Execution` section that runs
  `.specify/extensions/ov/scripts/bash/ov-<cmd>.sh`. Deterministic work (copying, checking,
  splitting, JSON/YAML edits) goes in scripts; only dialogue and judgment stay in the prompt.
- **Rationale**: Principle V (mechanisms over prose) and Principle II (agents don't author
  the SRS). Scripts are testable; prompts are not.
- **Filenames**: `speckit.ov.*.md`, `extension.yml`, `preset.yml` and `bundle.yml` are names
  spec-kit imposes (Principle I exception 1). Everything else is `ov-*`, including template
  sources (`templates/ov-agents.md` is installed as `AGENTS.md`, exception 3).

### R-4: `.aiignore` matching reuses git's own gitignore engine

- **Decision**: `ov-aiignore-match.sh` builds a throwaway bare repo whose `info/exclude` is
  the `.aiignore` content and runs
  `git --git-dir=<tmp> --work-tree=<empty dir> -c core.excludesFile=/dev/null check-ignore --no-index -q -- <path>`.
- **Rationale**: exact gitignore semantics (globs, `dir/`, `**`, `!negation`) without a
  bash re-implementation. The empty work tree and `/dev/null` excludes keep the repo's own
  `.gitignore` and the user's global excludes out. Prototyped here: `src/core/` blocks
  `src/core/a/b.rs` but not `src/corex.rs`; `*.lock` + `!keep.lock` behaves correctly;
  non-existent paths work.
- **Alternatives**: bash `[[ == ]]` globbing (wrong semantics for `**`, `dir/`, negation);
  `jq`/Python matchers (extra runtime).
- **Shared by**: the PreToolUse guard, the CI check, and the AI review's module mapping (R-9).

### R-5: Guard script contract (Claude Code PreToolUse)

- **Decision**: `ov-guard.sh` reads the hook JSON from stdin, takes `tool_input.file_path`
  (Edit/Write/MultiEdit) or `tool_input.notebook_path` (NotebookEdit), makes it relative to `$CLAUDE_PROJECT_DIR`, and exits **2** with
  a reason on stderr when the path matches. Exits 0 otherwise, including when `.aiignore` is
  missing (fail-open, spec edge case 1). Read is not in the matcher, so it is never blocked
  (FR-032). Paths outside the project are allowed.
- **Rationale**: exit 2 + stderr is a documented deny and passes cleanly through spec-kit's
  dispatcher (D-2). JSON field extraction uses `jq`, declared in `requires.tools`.
- **Mode-independent**: the guard reads only `.aiignore`, never `ov-config.yml`, so it is
  active in every authorship mode. (The earlier off-prefix branch check was removed along
  with the `branch` mode, 2026-10-15.)
- **Latency**: `tests/ov-guard-latency.test.sh` runs the guard 50 times on a listed path and
  fails if the median is above 200 ms (SC-007). To stay under budget, the throwaway git dir
  from R-4 is cached under `${TMPDIR:-/tmp}/ov-aiignore-<sha256 of .aiignore>`, so a warm call
  is one `jq` plus one `git check-ignore`.
- **Gap (accepted)**: writes through Bash are not intercepted. `AGENTS.md` says so and CI is
  the backstop (FR-014).
- **NotebookEdit (author decision)**: included. The matcher is
  `Edit|Write|MultiEdit|NotebookEdit`; NotebookEdit's path comes from `tool_input.notebook_path`.

### R-6: CI `.aiignore` check runs from the base branch, per commit

- **Decision**: `.github/workflows/ov-aiignore.yml`, trigger **`pull_request_target`**,
  check out the base branch, fetch the PR head (`refs/pull/<n>/head`, so fork PRs work too)
  without checking it out or running it. It runs on **all PRs, forks included** (FR-031). For
  each commit in `base..head`:
  - The commit is an agent commit if and only if its message matches
    `(?i)^co-authored-by:.*claude` or `^Assisted-by: claude-code$` (FR-034). Branch names play
    no role: the agent branch prefix was removed on 2026-10-15 (author decision).
  - Each agent commit's changed paths (`git diff-tree --no-renames -r --name-only`, so both
    sides of a rename count) are matched against the **base branch's** `.aiignore` using the
    **base branch's** copy of `ov-aiignore-match.sh`.
  - The job fails and lists commit + path pairs. Other commits may touch listed paths (FR-031).
- **Rationale**: with `pull_request`, the workflow definition and scripts come from the PR,
  so an agent PR could edit the check itself. `pull_request_target` runs the base
  definition, and never executing PR code keeps it safe. The default `.aiignore` template
  lists the enforcement files themselves: `.aiignore`, `.claude/settings.json`,
  `.github/workflows/ov-*.yml`, `.github/ov-ruleset-main.json`, `.specify/extensions/ov/**`,
  and `docs/srs/SRS.md` (FR-035). `docs/workspace.dsl` is deliberately **not** listed: it is
  shared and agent-editable (FR-040).
- **Alternatives**: `pull_request` + a CODEOWNERS rule on the workflow (needs approvals; the
  ruleset requires 0).

### R-7: AI review job

- **Decision**: `.github/workflows/ov-ai-review.yml` (`pull_request_target`), installed only
  when `ai_review: on`.
  - **Forks**: the first step compares `head.repo.full_name` with `github.repository`. For a
    fork it writes "fork PR: AI review skipped" to the job summary and exits 0
    (pass-with-skip, FR-058), before touching the secret and without invoking the model.
  - **Same-repo PRs**: it installs the Claude Code CLI and runs
  `claude -p` with `--output-format json` and read-only tools (`Read,Grep,Glob`). The prompt
  holds the PR diff plus the affected `docs/srs/modules/<module>.md` files, and the run must
  end with `OV-REVIEW: PASS` or `OV-REVIEW: FAIL`. Bash parses that line and sets the exit
  code. A missing `ANTHROPIC_API_KEY` secret fails the job first, with a message naming the
  secret (FR-056).
- **Rationale**: per the Claude Code docs, `anthropics/claude-code-action@v1` comments but
  does not fail the job by itself. A CLI step gives a deterministic pass/fail for a required
  check.
- **Risk**: the PR diff is untrusted input handed to a model in a job that holds a secret.
  Mitigations: read-only tools, no `Bash`, the model only runs for same-repo PRs, and no PR
  code is executed.

### R-8: `/ov-pr` artifacts

- **Config**: `.specify/extensions/ov/ov-config.yml` (spec-kit's `provides.config` mechanism,
  as in `git`), with flat keys `authorship`, `auto_merge`, `ai_review`, `configured`.
  The scripts read and write it line by line (flat `key: value`, no YAML library).
- **Authorship**: `coauthor` (default) leaves Claude Code's own attribution alone, which
  writes `Co-Authored-By: Claude <noreply@anthropic.com>`. `trailer` sets
  `attribution.commit: "Assisted-by: claude-code"` in `.claude/settings.json`; switching back
  to `coauthor` removes that key. No git hooks are installed: the `branch` mode, its
  commit-msg hook and `core.hooksPath` were dropped on 2026-10-15.
- **No branch prefix** (removed 2026-10-15): agent commits are identified by trailer only, on
  every branch. `CONTRIBUTING.md` states this (FR-051).
- **auto-merge**: `.github/workflows/ov-automerge.yml`, installed only when `auto_merge: on`.
  It runs `gh pr merge --auto --squash` on same-repo PRs only. Its first step compares
  `head.repo.full_name` with `github.repository` and skips fork PRs (FR-054). Squash is a
  default the author can change. The repo setting "Allow auto-merge" must be on (quickstart).
- **Ruleset**: `.github/ov-ruleset-main.json`, an importable GitHub ruleset. It requires
  status checks `ov-aiignore` (+ `ov-ai-review` when on), PRs, 0 approvals, and blocks
  direct pushes and force pushes.

### R-9: SRS split is a deterministic script

- **Decision**: the SRS template marks each module with a heading `## Module: <name>`.
  `ov-srs.sh split` writes `docs/srs/modules/<name>.md` = header line
  `<!-- GENERATED from SRS.md, do not edit -->` + the shared sections (purpose, scope) +
  that module's section. Orphaned module files are reported, not deleted (Scenario 4.3).
- **Rationale**: the agent never paraphrases the SRS (Principle II); output is reproducible.
- **`Paths:` (author decision)**: each module section has a `Paths:` line (gitignore-syntax
  globs). The AI review uses it to map changed files to modules (FR-057), reusing R-4's
  matcher. Without it, FR-057 has no mechanical mapping.

### R-10: Preset carries a synced copy of POLICY.md

- **Decision**: `presets/ov-policy/preset.yml` provides
  `{type: template, name: constitution-template, file: templates/ov-policy.md, strategy: prepend}`.
  `scripts/ov-sync-policy.sh` copies the repo's `POLICY.md` byte for byte into
  `templates/ov-policy.md`. The ov repo's CI fails if the copy differs or if POLICY.md does not
  start with `<!-- ov-policy -->`.
- **Rationale**: preset file paths may not escape the preset dir (`presets/_manifest.py:236`),
  and the project sets `allow_symlinks: false`. The copy is a derived artifact; POLICY.md
  itself is never written by an agent. Until the author writes POLICY.md, the copy holds only
  the marker line.

### R-11: Bundle

- **Decision**: `bundles/ov/bundle.yml` (`schema_version: "1.0"`, `bundle:` meta,
  `requires.speckit_version`, `integration: {id: claude}`, `extensions: [{id: ov, source: …}]`,
  `presets: [{id: ov-policy, source: …, strategy: prepend}]`), checked with
  `specify bundle validate`.
- **Risk**: the reference docs say little about bundles, and resolving local `source:`
  entries is unverified. If validation rejects local sources, the bundle ships for
  `specify bundle build` only, and installation stays `extension add` + `preset add`. The
  task list keeps this as an explicit verification step.

### R-12: Tests and repo CI

- **Decision**: plain bash test scripts `tests/ov-*.test.sh` with a small assertion helper,
  plus `shellcheck`, run by the ov repo's own `.github/workflows/ov-ci.yml`. The repo CI also
  runs `scripts/ov-lint-prefix.sh` (the Principle I mechanism, with an allowlist of the three
  exceptions) and the POLICY.md sync check.
- **Principle VI mechanism**: ov is dogfooded. Once the guard works, this repo installs
  `extensions/ov` in dev mode with an `.aiignore` listing `README.md`, `POLICY.md`,
  `.aiignore`, so agent edits to them are denied locally and fail CI.
- **Alternatives**: bats-core (extra dependency, little gain at this size).

### R-13: Scope statement

- **Decision**: `templates/ov-agents.md` contains, verbatim: "ov enforces autonomous agent
  loops. Augmented coding (human asks, human approves each edit) is outside its scope and
  reviewed manually by the owner." (FR-015). `tests/ov-init.test.sh` greps the installed
  `AGENTS.md` for that exact sentence.
- **POLICY.md**: the same sentence belongs in POLICY.md's marker section. The author writes it
  (Principle VI), and the sync check (R-10) then carries it into the preset copy. No task in
  this plan writes POLICY.md.
