---
name: vibe-map-bootstrap
description: Maintain the project's progress DAG with the vmap CLI. Use whenever the project has a .vmap/ directory or the user asks to add a goal/task, track progress, run audit, manage releases, or get a status report. Proactively call vmap after completing a piece of work — mark the task done, bump goal closure, refresh the human-facing .vmap/vibe-map.html.
---

# vibe-map skill

You are working in a project that uses [vibe-map](https://github.com/eanzhao/vibe-map) to track progress as a goal DAG. Use the `vmap` CLI to keep it in sync with your work. Every mutating command auto-refreshes `.vmap/vibe-map.html` for the human to see.

## Verify install before first use

```bash
vmap version         # prints "vmap <tag>" or "vmap dev" for local builds
vmap --version       # same value, short form
ls ~/.vmap/skills/   # SKILL.md cheatsheet.md vibe-map-bootstrap.md playbooks/
```

If `vmap` is missing:

```bash
curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh | bash
```

If `~/.local/bin` is not in `$PATH`, the installer prints the line to add to `~/.zshrc`.

## Upgrade awareness

vmap ships binary + skills as one tarball — they upgrade together. When you load this skill, **proactively check**:

```bash
vmap version --check
# Then compare the printed current version against the latest tag (the
# command prints the curl one-liner that fetches it).
```

If the local version is older than what's on GitHub Releases, suggest upgrading **before** doing project work:

```bash
vmap upgrade | bash
```

Trigger this proactive check when:

- It's the first interaction in a new session
- User says "vmap is old", "upgrade vmap", "what version", "is this latest"
- `vmap --version` reports a tag more than a few weeks old (you don't have the date directly; estimate via `git log`-like signals in the repo or just suggest the check)

## Mental model — the only thing that matters

- **goal** = a PRD-level user-visible capability ("用户能登录"). **NOT a code package.** If you're tempted to write `pkg-auth` as a goal id, stop and re-read the PRD.
- **task** = concrete implementation step under a goal. Often spans multiple files / packages.
- **release** = version boundary ("0.4.0"). Goals point at a release via the `milestone` field.
- **closure** is monotonic: `seed → obligation → scoped → public → bridged → mature`. The CLI refuses backward moves.
- **deps** are *semantic* dependencies between goals (and between tasks within a goal). Cycle detection runs automatically.

## When to invoke

Trigger words / situations:

| User says or you observe | First move |
|---|---|
| **`.vmap/` 不存在 + 代码已经一大坨**（冷启动场景） | Read `skills/playbooks/bootstrap-existing-codebase.md`. **Do not** blindly run `vmap backfill` — it gives a package-shaped DAG, which is not what we want. |
| "加一个 feature / 接到新需求 / 帮我做 X" | Read `skills/playbooks/new-feature.md`, run `vmap add goal ...` (semantic, not package) |
| "做完了 X" / "finished X" | `vmap update <id> --status done` (also `--add-test`, `--add-doc` if applicable) |
| "现在做到哪了" / "what's the status" / "where are we" | Read `skills/playbooks/daily-progress.md`, run `vmap status` or `vmap list goals --focus` |
| `vmap audit` reports violations (exit 3) | Read `skills/playbooks/audit-fix-loop.md`, fix each violation, re-audit |
| "准备发版 / ship a release" | Read `skills/playbooks/release-shipping.md` |
| You just finished a goal's last task | Bump `vmap update <goal-id> --closure scoped` (or further, per current stage) |

Also activate proactively when:

- After any non-trivial change to the codebase, **before reporting back to the user**, record the work as a task and mark it done.
- When the user describes their goal at the start of a session — capture it as a goal before writing code.
- When the user gives you a new project that has no `.vmap/` yet — trigger the cold-start playbook before doing anything else.

## Canonical playbooks

Detailed step-by-step guides — read on demand:

| Path | Purpose |
|---|---|
| `skills/SKILL.md` | Full work mode + 5-min quickstart + anti-patterns (this file is a summary; that one is the source) |
| `skills/cheatsheet.md` | Complete CLI flag reference |
| `skills/vibe-map-bootstrap.md` | The bootstrap prompt itself (mostly user-facing) |
| `skills/playbooks/bootstrap-existing-codebase.md` | **Cold start**: existing codebase, no `.vmap/` yet, need to build initial semantic DAG |
| `skills/playbooks/new-feature.md` | Adding a new feature/goal from a PRD-shaped request |
| `skills/playbooks/audit-fix-loop.md` | Audit-driven fix loop (missing_tests / missing_docs / missing_region_metadata) |
| `skills/playbooks/release-shipping.md` | Closing a release (status → closed, audit, tag) |
| `skills/playbooks/daily-progress.md` | "Where are we" reports |

## Most common commands

```bash
vmap status [--release K] [--json]
vmap show <id> [--json]
vmap list goals [--focus] [--release K] [--closure X] [--owner U] [--no-tests] [--json]
vmap list tasks [--goal G] [--status S] [--json]
vmap deps <id> [--upstream|--downstream] [--json]

vmap add goal --id g-xxx --title "..." --milestone 0.X.0 --focus
vmap add task --id t-xxx --goal g-xxx --title "..."
vmap update <id> --status done
vmap update <goal> --closure scoped   # monotonic
vmap update <id> --add-dep g-other    # incremental; full reset is --deps a,b,c
vmap update <id> --add-test path/test.mbt   # also --add-doc, --notes, --description, --goal (move task)
vmap rename <old> <new>

vmap release add <key> --label-en "..." --label-zh "..." --target YYYY-MM-DD --status open
vmap release assign <key> --goals g1,g2
vmap release update <key> --status closed
vmap release list [--json]

vmap audit [--json]     # exit 3 on violations
```

For batch operations (audit fix loops, scripted edits), pass `--no-render` to skip the per-command HTML refresh, then `vmap render --out .vmap/vibe-map.html` once at the end.

## Anti-patterns (don't)

1. **Goals named after packages** (`pkg-core`, `auth-package`). Goals are PRD concepts.
2. **Forgetting to update closure** after meaningful progress. Closure is the human's main forward-motion signal.
3. **Hand-editing `.vmap/vibe-map.json`**. Go through vmap CLI — it does cycle detection + state machine validation + auto-render.
4. **Skipping audit at release boundaries**. Audit is the objective "is this really finished" signal.
5. **Adding `--milestone X` where X is not a registered release key**. `vmap audit` will flag it as `release_unknown` once releases are configured.

## Exit codes (for fix loops)

| code | meaning | what to do |
|---|---|---|
| 0 | success | continue |
| 1 | business validation (cycle, duplicate id, unknown reference, release status regression) | read stderr, adjust args |
| 2 | CLI argument error | check the flag spelling |
| 3 | `vmap audit` found violations | run the audit-fix loop |

All read-only commands support `--json`. Use it whenever you need to parse output.

## Self-test (when this skill is freshly loaded)

To confirm vmap is functional:

```bash
vmap status | head -5
vmap list goals --focus | head -10
vmap release list | head -5
```

If any of those error out, the project isn't initialized:

- **If the codebase already has code in it** (most common case for existing projects): run the cold-start playbook → `skills/playbooks/bootstrap-existing-codebase.md`. Do NOT default to `vmap init` + start adding goals from scratch; first read the code + README so the initial DAG is semantic, not blank.
- **If the codebase is empty / brand new**: `vmap init --name "<project>"` is fine. Remind user to add `.vmap/` to `.gitignore`.
