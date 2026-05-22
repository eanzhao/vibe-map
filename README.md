**English** | [简体中文](README_zh.md)

# vibe-map

> A goal DAG that coding agents maintain and humans watch — Lean 4 region map style, rendered as a live `.vmap/vibe-map.html`.

![vibe-map dashboard](https://raw.githubusercontent.com/eanzhao/vibe-map/master/examples/dashboard.png)

> The screenshot is vibe-map's own self-map. `examples/dag.html` is the live version — `open` it locally.

## Vision

In the vibe-coding era the AI is the primary author and the human watches and steers. Two pieces of state matter constantly: *where are we?* and *what would break if we shipped the next thing?* Neither GitHub issues nor a flat todo list answer them.

`vibe-map` ships as **a `vmap` CLI plus a bundle of skills**. The CLI is small. The artifact the user actually consumes is a single file — `.vmap/vibe-map.html` — a live execution map of the goal DAG: what's done, what's next, what's blocked, and what the next ship would break.

The long-term picture (much of it still unfinished):

1. **Coding-agent first.** This whole project is *for coding agents*. No PM UI, no IDE plugin, no daemon. Just a CLI an agent can `exec` plus skills it can read.
2. **Greenfield → DAG.** For a brand-new project, the agent brainstorms with the user (paired with skills like [gstack](https://github.com/gstack/gstack)), then uses vibe-map to decompose the resulting docs into goals and tasks — producing an actionable `.vmap/vibe-map.html`.
3. **Brownfield → DAG.** For a project that already has some code, the agent uses vibe-map to recover the goals it has already shipped, and continues forward from there.
4. **Regression suite per goal.** Every goal carries the tests that prove it works. The user can run the full regression suite at any time. When a new goal breaks an older one, vibe-map points at *exactly which goal regressed* — the user (or the agent on their behalf) fixes per vibe-map's hint, or adjusts the goal definition if reality has moved.
5. **End-to-end loop.** Once the user's idea has been refined enough — polished through gstack, or just thoroughly self-recorded — they hand it to a coding agent. vibe-map turns it into a DAG, the agent ships it goal by goal, and the loop only stops when the original idea is delivered.
6. **Open.** Issues, forks and PRs welcome.

Where each point stands today is summarized in [Status](#status).

## Install

```bash
# macOS arm64 / Linux x86_64 / Linux arm64 — prebuilt
curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh | bash
```

This drops `vmap` into `~/.local/bin/` and skills into `~/.vmap/skills/`. If `~/.local/bin` is not on your `$PATH`, the installer prints the line to add to your shell rc.

> Intel Mac (`darwin-x86_64`) is not in the prebuilt matrix yet (GitHub Actions `macos-13` queue is too slow). Build from source for now.

**From source** (MoonBit toolchain + local hacking):

```bash
git clone https://github.com/eanzhao/vibe-map && cd vibe-map
moon install && moon build --target native --release
./install.sh --local "$PWD"
```

Distribution design: [`docs/distribution.md`](docs/distribution.md).

## Drop this prompt into any coding agent

Paste the block below into Claude Code, Codex, Cursor — whichever agent you use. It will install vmap, read the rules, and start maintaining the DAG inside your project.

````text
Help me track this project's progress with vibe-map (vmap).

If vmap isn't installed yet:
  curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh | bash
  # If ~/.local/bin isn't on PATH, follow the script's hint and source your shell rc

Read the rules (required):
  cat ~/.vmap/skills/SKILL.md
  ls ~/.vmap/skills/playbooks/

Initialize at the project root (if .vmap/ doesn't exist):
  vmap init --name "<my project>"
  # Add .vmap/ to .gitignore

From then on, every piece of progress goes through the vmap CLI:
  - I describe a requirement → you extract goals at the PRD level (semantic, not by code package!) with vmap add goal
  - You break work into tasks: vmap add task --deps ...
  - You finish a task: vmap update <id> --status done
  - You promote a goal: vmap update <goal> --closure scoped/public/...
  - At key checkpoints: vmap audit, then fix tests/docs per the violations

Constraints:
  - A goal is a "user-perceivable capability" on the PRD, not a code package
  - closure is monotonic (seed → obligation → scoped → public → bridged → mature), never regress
  - Never hand-edit .vmap/vibe-map.json — everything goes through the vmap CLI
  - Exit codes: 1 = business error / 2 = bad args / 3 = audit violation

Playbook lookups in ~/.vmap/skills/playbooks/:
  new-feature.md / audit-fix-loop.md / release-shipping.md / daily-progress.md
  codex-goal-implement-loop.md / codex-architecture-refactor-loop.md
Command cheatsheet: ~/.vmap/skills/cheatsheet.md.

Every mutating vmap command auto-refreshes .vmap/vibe-map.html, which I'll keep open. Go.
````

Longer version with debugging tips: [`skills/vibe-map-bootstrap.md`](skills/vibe-map-bootstrap.md). If your repo already has `.claude/skills/vibe-map-bootstrap/SKILL.md` (vibe-map ships one), Claude Code auto-loads it — no copy-paste needed.

## Delegated Codex loops

vibe-map can also guide a controller agent that delegates the actual code changes to Codex CLI:

- [`codex-goal-implement-loop.md`](skills/playbooks/codex-goal-implement-loop.md) uses the DAG as a task queue: controller reads a vmap task, materializes the docs/tests/architecture context, runs `codex exec` in a worktree, reviews the diff, then updates vmap.
- [`codex-architecture-refactor-loop.md`](skills/playbooks/codex-architecture-refactor-loop.md) turns `AGENTS.md`, `CLAUDE.md`, and architecture docs into an explicit rule set, asks Codex to audit violations, writes each refactor cluster back as a vmap task, and loops through implement/review/verify.

The important split: the controller owns vmap state and git/PR topology; Codex subprocesses own source edits. The rendered `.vmap/vibe-map.html` stays the human-visible status surface.

## What vibe-map models

Progress lives as a DAG:

- **goal** — a *semantic* deliverable on the PRD ("users can log in", "supports release lanes") — not a code package
- **task** — the concrete steps that deliver a goal; tasks routinely span multiple source files / packages
- **release** — a version boundary ("0.5.2") that groups goals and tells the agent *what this version is about*
- **edges** are at the semantic layer — not the source-code-import layer

The coding agent edits the graph through CLI calls; the human watches the rendered HTML — region-map styled, finished work in solid color, in-flight nodes glowing, future scope fading into the background.

> Terminology: `goal` / `task` rather than `milestone` / `issue` to avoid collision with GitHub's own concepts. The "region map" visual is borrowed from Lean 4 — `goal` / `focus` / `closure` are the same family of ideas.

## Designed for coding agents

Every command has `--json` output and a stable exit code:

| code | meaning |
|---|---|
| 0 | success |
| 1 | business validation failed (cycle, duplicate id, unknown node, release validation, ...) |
| 2 | CLI argument error |
| 3 | `audit` violations (drives the fix-and-retry loop) |

All state lives in a single `vibe-map.json`. No MCP, no daemon, no IDE plugin — just a binary the agent can `exec`.

## Three ways to load data

In decreasing order of importance:

### 1. Live tracking — primary

The agent records as it reads the PRD / design docs. This is the canonical workflow:

```bash
vmap init --name "<my project>"
vmap add goal --id g-login --title "users can log in"
vmap add task --id t-auth --goal g-login --title "auth middleware" --regression-testable
vmap update t-auth --status done --tests "src/auth/middleware_test.mbt"
```

### 2. Plan — secondary (extract todos from markdown)

Scan markdown and synthesize goals/tasks:

```bash
vmap plan --docs ROADMAP.md docs/         # default: extract `- [ ]` checklist items
vmap plan --docs TODOS.md --format tlist  # extract `## T<N> — title` + `**Status:**`
```

Code blocks and already-checked items are skipped; reruns are idempotent.

> Today `plan` only handles explicit checklists. Pulling *semantic* goals from free-form PRD text is on the 1.0.0 roadmap (`goal-llm-plan`) — and unblocks vision point 2.

### 3. Backfill — rescue tool (recover goals from existing code)

For codebases that already exist but were never tracked. **One goal per package, one done task per file:**

```bash
vmap backfill --src . --template moonbit      # built-in: moonbit | typescript | dotnet
vmap backfill --src . --template-file path.json
```

> ⚠️ Useful only for retroactive recovery. **Product capability dependencies ≠ code package structure** — backfilled goals are package-shaped, not PRD-shaped. Once the project is running, the main entry point should return to live tracking.

## Release lanes

The thing vibe-coding gets wrong most often: AI has no sense of version boundary and won't stop adding scope. Release lanes model that:

```bash
vmap release add 0.5.2 --label-en "publish to mooncakes.io" --label-zh "发布到 mooncakes.io" \
                       --target 2026-05-20 --status open
vmap release assign 0.5.2 --goals goal-publish,goal-licensing
vmap status --release 0.5.2           # text, filtered to one release
vmap status --release 0.5.2 --json    # AI-loop friendly
vmap release list [--json]
```

`status` is a monotonic state machine: `planned → open → closed`, no regressions (`ReleaseStatusRegression`). Goals reference a release via `milestone`. Soft validation — only enforced when `releases` is non-empty, so legacy `milestone="anything"` data isn't blocked.

## Quality gate: `vmap audit`

```bash
vmap audit               # text
vmap audit --json        # JSON
echo $?                  # 0 clean / 3 violations
```

Today's rules:

- `regression_testable: true` but `tests: []` → `missing_tests`
- `status != todo` but `docs: []` → `missing_docs`
- goal missing region metadata (closure / owner / `issue_count` / `focus` / `archived` / `promoted_at` / `gh_query`) → `missing_region_metadata`

GitHub issue drift is checked by a separate script (depends on `gh` CLI):

```bash
python3 tools/audit_github.py --file vibe-map.json [--strict] [--markdown]
```

The agent's audit loop looks roughly like:

```
vmap audit --json > /tmp/v
# parse violations → write tests for each missing_tests / write docs for each missing_docs / fill region metadata
# vmap update <id> --tests ... / --docs ... / --owner ...
# audit again until exit 0
```

> Today `audit` checks that tests are *listed*. **Actually running the regression suite and gating on it — vision point 4 — is `goal-regression-runner`, not yet started.**

## Visualization

```bash
vmap render --out examples/dag.html
open examples/dag.html
```

- Dark canvas goal DAG with glowing nodes, dotted background, drag / zoom / fit-to-view
- **Canvas shows only goals**; tasks are collapsed into the goal detail panel
- **Color = closure tier**: seed → obligation → scoped → public → bridged → mature
- **Size = `issue_count`**; red border = current focus; semi-transparent = archived
- Left progress panel (per goal) + search + product filter + status buttons (all / focus / in-progress / archived)
- Right node detail: closure / formal / owner / product / milestone / promoted_at / tests / docs / notes per task
- Click a node → highlight its full transitive dependency chain
- Single self-contained HTML — no CDN, no framework runtime

`examples/dag.html` is vibe-map's own self-map.

## CLI at a glance

```
vmap init                              create vibe-map.json
vmap add goal …                        add a goal
vmap add task …                        add a task
vmap update <id> …                     edit any field (unset flags don't touch existing values)
vmap rm <id>                           remove a goal or task
vmap rename <old> <new>                rename id (rewrites deps + task.goal refs)
vmap show <id> [--json]                full detail for one node (tasks / upstream / downstream)
vmap list goals [filters] [--json]     list goals with filtering
vmap list tasks [filters] [--json]     list tasks with filtering
vmap deps <id> [--upstream/--downstream/--json]  transitive deps graph
vmap import --in <path>                bulk-load a hand-written vibe-map.json (validate + write)
vmap render --out X.html               render visualization HTML
vmap status [--json] [--release K]     summary text / JSON (optionally per release)
vmap audit [--json]                    quality gate
vmap coverage [--json]                 how much of docs / src / issues the DAG references
vmap doctor [--json]                   health alerts (density / lane / orphan / mismatch)
vmap backfill --src DIR                rescue tool: recover goals from source
vmap plan --docs F,…                   extract from markdown
vmap release add <key>                 add a release lane
vmap release list [--json]             list releases
vmap release update <key> --status/--target/--label-en/--label-zh/--notes
vmap release assign <key> --goals      assign goals to a release
vmap release unassign <key> [--goals]  remove goals from a release (default: all)
vmap release rm <key> [--force]        delete a release (--force if it has members)
vmap version [--check]                 print version
vmap upgrade                           print the upgrade command (pipe through bash to run)
```

Full flags via `--help` on each subcommand.

`vmap update <id>` fields (general + per-kind):

- **general**: `--title`, `--regression-testable`, `--tests a,b,c` (replace), `--add-test`/`--remove-test`, `--docs`/`--add-doc`/`--remove-doc`, `--deps a,b,c` (replace), `--add-dep`/`--remove-dep`
- **goal only**: `--description`, `--closure`, `--formal`, `--product`, `--milestone`, `--owner`, `--issue-count`, `--focus`/`--archived`, `--promoted-at key=date,…`, `--gh-query`
- **task only**: `--status`, `--notes`, `--goal <new-goal>` (move task between goals)

`closure` is monotonic (no regression). `add-dep` runs cycle detection. `rename` rewrites every `deps` reference and `task.goal` pointer.

## Data model

State lives in `vibe-map.json`. The agent reads it directly:

```jsonc
{
  "config": { /* products / closure_tiers / formal_levels / ui */ },
  "project": { "name": "...", "description": "..." },
  "releases": [
    { "key": "0.5.2", "label": {"en":"publish to mooncakes.io","zh":"发布到 mooncakes.io"},
      "target": "2026-05-20", "status": "planned|open|closed", "closed_at": null }
  ],
  "goals": [{
    "id": "goal-login",
    "title": "users can log in",
    "deps": ["goal-schema"],            // cross-goal deps at the semantic layer
    "closure": "scoped",                // seed → obligation → scoped → public → bridged → mature (monotonic)
    "formal": "checked",                // none / sop / checked / audited
    "product": "default",
    "milestone": "0.5.2",               // points at release.key (soft-validated)
    "owner": "eanzhao",
    "issue_count": 3,
    "focus": true,
    "archived": false,
    "promoted_at": { "scoped": "2026-05-19" },
    "gh_query": "is:issue label:goal-login",
    "regression_testable": true,
    "tests": [], "docs": []
  }],
  "tasks": [{
    "id": "t-auth", "goal": "goal-login",
    "title": "auth middleware",
    "status": "todo | in-progress | blocked | done",
    "deps": [],                         // same-layer task deps
    "notes": "",
    "regression_testable": true,
    "tests": [], "docs": []
  }]
}
```

Older JSON missing newer fields still loads (Option fields default to None). `closure` monotonicity is enforced in `set_goal_closure`. Release lanes are soft-validated: keys are only checked against `releases` when that list is non-empty.

## Status

> Machine-friendly: `vmap release list --json`. Human-friendly below.

### Currently in flight — 0.4.0 (release modeling + audit + viz polish, target 2026-06-15)

| Goal | State |
|---|---|
| **goal-release-modeling** — release lanes (data + CLI) | Stage 1 ✓ (add/list/update/assign/unassign/rm, status --release, release_progress); Stage 2 pending (release status / close) |
| **goal-cli-dag-mgmt** — CLI surface the agent uses to drive the DAG | ✓ `update --deps/--add-dep/--remove-dep/--goal/--notes/--description/--add-test/--remove-test/--add-doc/--remove-doc`, `show <id>`, `list goals/tasks` (filtering), `deps <id>` (transitive), `rename <old> <new>` |
| **goal-audit** — audit rule expansion | Base rules ✓; pending: release_blocked / release_unknown / `audit --release` filtering |
| **goal-viz** — release dimension in the viz | Base viz ✓; pending: release dropdown filter, group-by-release on the left panel |

### Planned — 0.6.x → 1.0.0 (and the vision)

| Goal | Vision link | Notes |
|---|---|---|
| **goal-llm-plan** | point 2 (greenfield → DAG) | Upgrade `vmap plan`: extract *semantic* goals from free-form PRD text, not just `- [ ]` checklists |
| **goal-regression-runner** | point 4 (regression suite per goal) | Actually run the tests attached to every goal, gate new ships on them, point at the exact regressed goal when something breaks. Today `audit` only checks tests are *listed*, not that they pass. |
| **goal-greenfield-bootstrap** | point 2 | Tighter loop between brainstorm-style skills (gstack and similar) and `vmap plan` — agent walks the user from raw idea to a full DAG without manual copy-paste |
| **goal-cross-language** | — | Rust / Go / Python templates for `backfill` (rescue tool broadcast) |
| **goal-schema-freeze** | — | `schema_version` field + upgrade path + stable schema doc |

### Shipped

| Release | Date | Contents |
|---|---|---|
| **0.1.0** | 2026-05-15 | Live tracking: `init / add goal / add task / update / rm`, JSON persistence, cycle detection, stable exit-code contract |
| **0.2.0** | 2026-05-17 | Plan (checklist + tlist), Backfill (moonbit / typescript / dotnet templates), base visualization (HTML, product/search/status filters, node detail), base Audit (tests / docs / region metadata), GitHub issue drift script |
| **0.3.0** | 2026-05-18 | Terminology rename: Milestone → Goal, Issue → Task (isolating from GitHub's concepts) |
| **0.5.0** | 2026-05-19 | The all-in-one coding-agent experience: `install.sh` (curl \| bash) + skills bundle (SKILL.md / cheatsheet / playbooks / vibe-map-bootstrap) + `.vmap/` default path + auto-render of `.vmap/vibe-map.html` on every mutating command + `vmap version` / `vmap upgrade` + 12 cli-dag-mgmt commands + release lanes (base) + node detail modal |
| **0.5.1** | 2026-05-19 | Skill refresh: agent now reads GitHub issues (`gh issue list`) as a PRD signal during bootstrap |
| **0.5.2** | 2026-05-20 | `vmap coverage` (docs/src/issues coverage) + `vmap doctor` (density / lane / orphan / mismatch warnings); published to [mooncakes.io](https://mooncakes.io/docs/eanzhao/vibe-map) under MIT |
| **0.5.3** | 2026-05-20 | `vibe-map.html` frontend: double-click a sidebar goal row to open its detail modal, GitHub URLs across the page become new-tab links, double-click an expanded task card for a dedicated task detail modal |
| **0.6.0** | 2026-05-21 | Release modeling Stage 2, Audit Stage 2, Visualizer Stage 3 & AI Regression Context: `vmap release status` / `close` CLI subcommands (with target-specific FFI date retrieval), `vmap audit --release` filtering, core release audit rules (`release_unknown` & `release_blocked`), HTML visualizer sidebar release grouping & filter dropdown, and `vmap regression prompt` to compile structured markdown diagnostics context for external AI agents |
| **0.6.1** | 2026-05-22 | Regression Probes Dashboard & Runner: Added automated regression sweep runner `vmap regression run` (cross-platform FFI command execution), left progress sidebar tab-switcher to display Probes status dashboard (Passed/Failed/Missing/Pending), and detailed execution stats/warnings rendering inside `vibe-map.html` |
| **0.7.1** | 2026-05-23 | Delegated Codex loops: added `codex-goal-implement-loop` and `codex-architecture-refactor-loop` playbooks, prompt templates, and a cross-platform `spawn-codex.sh` wrapper so a controller agent can delegate implementation/review/refactor work to Codex CLI while keeping vmap as the visible state surface |


## Contributing

Issues, forks and PRs are welcome — file at [github.com/eanzhao/vibe-map](https://github.com/eanzhao/vibe-map). The project is bilingual (English / 简体中文); either is fine.

If you're proposing a new direction, opening an issue first saves rework — the long-term shape (see [Vision](#vision)) is opinionated.

## Build

[MoonBit](https://www.moonbitlang.com/):

```bash
moon install                # fetch moonbitlang/x
moon build --target native  # outputs _build/native/debug/build/cmd/vmap/vmap.exe
moon test                   # 63 tests
moon fmt && moon check
```

## License

MIT — see [`LICENSE`](LICENSE).
