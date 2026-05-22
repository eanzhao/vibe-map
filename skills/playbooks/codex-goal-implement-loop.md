# Codex Goal Implement Loop

适用场景：项目已经有 `.vmap/`，用户明确让当前 agent **调用 Codex CLI** 去实现某个 goal / task，而不是让当前 agent 亲手改代码。

这份 playbook 把 vibe-map 变成执行队列，把 Codex CLI 变成实现工人。当前 agent 是 controller：负责读 DAG、整理上下文、派 `codex exec`、验收结果、更新 vmap；Codex 子进程负责改源码和测试。

支撑文件都在 `~/.vmap/skills/playbooks/codex-loops/`：

- `prompts/goal-implement.md` — implement codex 模板
- `prompts/goal-fix.md` — fix codex 模板
- `prompts/goal-review.md` — reviewer codex 模板（anti-sycophancy）
- `scripts/spawn-codex.sh` — codex exec 包装（强制 ≥3600s timeout、stdin 喂 prompt、写 EXIT/DONE_AT 尾、检查未解析 `{{...}}`）

## 0. Controller 原则

- Controller 不直接写 production code。它只改 `.vmap/` 状态、loop artifact、prompt、git/PR 元数据。
- Codex 子进程每次只拿一个明确 task，不能自己扩 scope、改 DAG 结构、擅自开新 goal。
- 项目规则必须随 prompt 一起给 Codex：优先读 `AGENTS.md`、`CLAUDE.md`、`.cursor/rules/`、目录内更近的 AGENTS、`docs/architecture*`、`docs/canon/`。规则冲突时按"更近目录 + 更具体文件 + 更明确用户指令"优先；仍冲突就停下来标 blocked。
- vmap 是人的可视化状态面。每次派出、通过、返工、卡住，都要同步 `vmap update`，让 `.vmap/vibe-map.html` 诚实反映进度。
- Codex 输出必须可验收：有 diff、有测试、有最终 marker、有 summary 文件。
- **路径纪律**：worktree 当 cwd 时 `.vmap` 会解析到子 worktree。所有给 Codex 的 prompt 内 `.vmap/...` artifact 路径**必须是绝对路径**（基于主 repo root），不要写相对路径。

## 0.5 预检（每个 loop 开始一次）

```bash
# Codex CLI
command -v codex >/dev/null || { echo "请装 Codex CLI: https://github.com/openai/codex"; exit 1; }

# spawn 脚本
ls ~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh

# vmap 数据
test -f .vmap/vibe-map.json || { echo "先 vmap init"; exit 1; }
```

成本提醒：一次 implement codex 通常 30-90 min wall + 几万 token。**先在一个小 task 上验 prompt 质量**，再放开跑大 task。

## 1. 选择目标

如果用户指定了 goal / task：

```bash
vmap show <id>
vmap deps <id>
```

如果用户只说"继续实现"：

```bash
vmap list goals --focus --json
vmap list tasks --status todo --json
```

优先选 deps 已完成、docs/tests 线索完整、用户刚刚点名的 task。不要绕过 DAG 凭感觉挑活。

## 2. 建 loop 目录

```bash
ROOT="$(pwd)"
mkdir -p "$ROOT/.vmap/codex-implement-loop/"{logs,runs,prompts,reviews,worktrees}
```

`.vmap/` 已经被 vibe-map 默认 gitignore 兜住，loop artifact 不会污染 git。

写一个小的 resume state 方便断点续跑：

```json
{
  "schema_version": 1,
  "mode": "codex-goal-implement-loop",
  "current_task": "<task-id>",
  "review_round": 0,
  "max_review_rounds": 3,
  "landing": "local-merge | branch-only | github-pr",
  "log_paths": {
    "implement": ".vmap/codex-implement-loop/logs/<task-id>-implement.log"
  }
}
```

**state 只是恢复提示，不是事实源**。事实源是 vmap 当前状态、git diff、Codex log marker、测试结果、PR 状态。

## 3. 命名约定

```
prompts/
  <task-id>-implement.md
  <task-id>-fix-r<N>.md
  <task-id>-review-r<N>.md
logs/
  <task-id>-implement.log
  <task-id>-fix-r<N>.log
  <task-id>-review-r<N>.log
runs/
  <task-id>-implement-summary.md
  <task-id>-fix-r<N>-summary.md
reviews/
  <task-id>-review-r<N>.md           # reviewer codex 写的 verdict 文件
worktrees/
  <task-id>/                          # git worktree path
```

文件用 `<task-id>` 而不是序号，方便 sweep / grep。

## 4. 材料化 prompt（绝对路径 + 项目命令）

复制模板到本地、用 `sed` 替换 `{{var}}`：

```bash
ROOT="$(pwd)"
TASK_ID="t-oauth-callback"
WT="$ROOT/.vmap/codex-implement-loop/worktrees/$TASK_ID"
BRANCH="vmap/$(date +%Y-%m-%d)_$TASK_ID"
PROMPT_OUT="$ROOT/.vmap/codex-implement-loop/prompts/$TASK_ID-implement.md"
SUMMARY_OUT="$ROOT/.vmap/codex-implement-loop/runs/$TASK_ID-implement-summary.md"

# 项目命令（从 Makefile / package.json / build 配置 / vmap docs 抽取）
BUILD_CMDS="moon build --target native"
TEST_CMDS="moon test"
GUARD_CMDS="moon check && vmap audit"

# 上下文 dump
VMAP_SHOW=$(vmap show "$TASK_ID")
RULES_DUMP=$(cat AGENTS.md CLAUDE.md 2>/dev/null | head -500)   # 截首 500 行避免超长
DOCS_DUMP=$(vmap show "$TASK_ID" --json | jq -r '.docs[]?' | xargs -I{} sh -c 'echo "--- {} ---"; cat {} 2>/dev/null | head -100')

# 把 dump 写进临时文件再 sed 进 prompt（避免 dump 内含 sed 特殊字符）
TMP=$(mktemp -d)
printf '%s\n' "$VMAP_SHOW" > "$TMP/vmap"
printf '%s\n' "$RULES_DUMP" > "$TMP/rules"
printf '%s\n' "$DOCS_DUMP" > "$TMP/docs"

python3 - "$ROOT" "$TASK_ID" "$WT" "$BRANCH" "$SUMMARY_OUT" \
  "$BUILD_CMDS" "$TEST_CMDS" "$GUARD_CMDS" \
  "$TMP/vmap" "$TMP/rules" "$TMP/docs" \
  "$PROMPT_OUT" <<'PY'
import sys, pathlib
root, task_id, wt, branch, summary, build, test, guard, vmap_f, rules_f, docs_f, out = sys.argv[1:]
tmpl = pathlib.Path.home().joinpath(".vmap/skills/playbooks/codex-loops/prompts/goal-implement.md").read_text()
subs = {
    "task_id": task_id,
    "task_title": "<task title — controller 应该已经从 vmap show 拿>",
    "repo_root": root,
    "worktree_path": wt,
    "branch": branch,
    "summary_output_path": summary,
    "build_commands": build,
    "test_commands": test,
    "guard_commands": guard,
    "vmap_show_dump": pathlib.Path(vmap_f).read_text(),
    "architecture_rules_dump": pathlib.Path(rules_f).read_text(),
    "docs_dump": pathlib.Path(docs_f).read_text(),
    "resume_header": "",     # 见 §8 crash 恢复
}
for k, v in subs.items():
    tmpl = tmpl.replace("{{" + k + "}}", v)
pathlib.Path(out).write_text(tmpl)
PY
```

**完成后必查**：`grep -n '{{' "$PROMPT_OUT" | head` 必须为空。任何未解析的 `{{var}}` 都会被 `spawn-codex.sh` 拦下。

## 5. Worktree + 派 Codex

```bash
git worktree add -b "$BRANCH" "$WT" HEAD

vmap update "$TASK_ID" --status in-progress \
  --notes "codex-loop:running: implement; log=.vmap/codex-implement-loop/logs/$TASK_ID-implement.log; worktree=$WT"
```

**vmap notes 前缀约定**：所有 codex loop 写进 notes 的状态都以 `codex-loop:` 开头，后面跟 `running|done|design-needed|review-cap|codex-crash|conflict|human-decision` + 短描述。这样：

- `vmap list tasks --status in-progress | grep codex-loop:` 一眼看出哪些是 codex 在跑
- `vmap list tasks --status blocked | grep codex-loop:` 一眼看出 codex loop 卡哪了
- 未来 viz 可以按 notes 前缀给 task 加 🤖 角标

派 codex：

```bash
LOG="$ROOT/.vmap/codex-implement-loop/logs/$TASK_ID-implement.log"

~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh \
  --cd "$WT" \
  --add-dir "$ROOT" \
  --prompt "$PROMPT_OUT" \
  --log "$LOG" \
  --timeout 5400 \
  --sandbox workspace-write
```

### 5.1 后台 vs 同步

**Claude Code / 其它支持 `task-notification` 的宿主**：用 Bash tool with `run_in_background: true` 派上面的命令。Codex 退出时 harness 自动唤醒 controller。同 turn 内 `ScheduleWakeup` 排一个 30 分钟 fallback，然后 end turn。**禁止**同步等 60-90 min（token 会爆 + /clear 后丢追踪）。

**其它宿主**：同步跑完这一轮。但不要假装无人值守——告知用户每个 task 要等 30-90 分钟。

### 5.2 Sandbox 模式权衡

- 默认 `--sandbox workspace-write`：codex 只能写 worktree（+ `--add-dir` 列出的目录），网络受限。最安全，能跑大多数纯本地测试。
- `--sandbox danger-full-access`：测试需要 docker / 网络 / 外部进程时才用，**只对你写的 prompt 用**。
- `--dangerously-bypass-approvals-and-sandbox`：仅在你的 runtime 本身已经被外部沙箱隔离时（aevatar 那种场景）才用，vibe-map 默认不推荐。

## 6. Controller 验收

Codex 结束后（task-notification 触发或同步返回），controller 验收，**不直接修代码**：

```bash
tail -40 "$LOG"
grep "VMAP_CODEX_IMPLEMENT_DONE:" "$LOG" | tail -1
git -C "$WT" status --short
git -C "$WT" diff --stat
test -f "$SUMMARY_OUT" && head -30 "$SUMMARY_OUT"
```

必须满足：

- log 末尾有 `VMAP_CODEX_IMPLEMENT_DONE:<task-id>:ok`
- worktree 有真实 diff
- summary 文件存在且列了 Files changed / Tests run
- task 记录的测试或最近包级测试已经跑过

### 6.1 Marker 缺失 / 不匹配怎么办

- log 末尾无 `VMAP_CODEX_IMPLEMENT_DONE` 但 `EXIT=0` → codex 跑完没遵守 marker 协议。**重派一次**，prompt 头部加 `resume_header`：

  ```
  上一轮你忘了打印末尾的 VMAP_CODEX_IMPLEMENT_DONE:<task-id>:<status> marker。
  这次必须严格按 prompt 流程第 9 步的精确格式打印，否则视为失败。
  worktree 已有上一轮改动，复用，不要重做。
  ```

- log 末尾 `EXIT=124`（timeout）→ 改 `--timeout` 上调或拆 task；不要无脑重派。
- log 末尾 `EXIT=127` → spawn 检测到 codex 不存在；先 §0.5 装好。
- log 含未解析 `{{var}}` 报错 → 回 §4 重 materialize。

连续 2 次失败 → 视为 codex-crash，下方 §9 标 blocked。

### 6.2 跑 vmap-native 验收（强制）

```bash
vmap audit          # codex 改了源代码但没回写 vmap docs/tests？audit 报红
vmap doctor         # 整体健康
vmap coverage       # codex 新增的代码是否在某 task 的 docs 中
```

任一报红 → 视为 **rework**（不是 codex 写代码错了，是 vmap 状态没跟上）。补 `vmap update --add-test / --add-doc` 再重新审视：

- 如果只是 metadata 缺失（codex 写了测试但 task `tests:` 没引），controller 自己补 `vmap update --add-test <path>`，无需重派 codex。
- 如果是更深的 DAG drift（task 拆得不对 / 缺 goal），停下来回维护模式，告知用户。

## 7. Review codex（独立轮）

再做独立 review。优先用 Codex review 子命令（轻量）：

```bash
REVIEW_OUT="$ROOT/.vmap/codex-implement-loop/reviews/$TASK_ID-review-r1.md"

cd "$WT" && codex exec review --uncommitted \
  --output-last-message "$REVIEW_OUT" \
  "Review this change against $ROOT/.vmap/codex-implement-loop/runs/$TASK_ID-implement-summary.md and the task. End with VMAP_CODEX_REVIEW:<pass|rework|abort>:<headline>."
```

但 codex review 默认 prompt 偏 sycophancy，**borderline pass 会带 bug 上线**。建议用 `~/.vmap/skills/playbooks/codex-loops/prompts/goal-review.md` 模板派一个完整 reviewer codex（同样的 materialize 流程，timeout 1800-3600s），它强制：

- 按维度逐项检查（task 意图 / 规则 / scope / 测试 / DAG / 红线）
- 每个 finding 必须引用 `file:line` + 规则原文
- Round > 1 必须显式 diff 上一轮 findings
- Bias 偏 `rework`（"borderline pass = ship a bug"）

```bash
~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh \
  --cd "$WT" --add-dir "$ROOT" \
  --prompt "$ROOT/.vmap/codex-implement-loop/prompts/$TASK_ID-review-r1.md" \
  --log "$ROOT/.vmap/codex-implement-loop/logs/$TASK_ID-review-r1.log" \
  --timeout 3600
```

如果项目暂时没有自定义规则需要 review 兜，临时退到 `codex exec review --uncommitted` 也 OK。

## 8. 返工循环

如果 review 是 `rework`，材料化 fix prompt（`prompts/goal-fix.md` 模板）：

```bash
ROUND=2
FIX_PROMPT="$ROOT/.vmap/codex-implement-loop/prompts/$TASK_ID-fix-r$ROUND.md"
FIX_SUMMARY="$ROOT/.vmap/codex-implement-loop/runs/$TASK_ID-fix-r$ROUND-summary.md"

# sed 替换 {{var}} → review_report_path, prior_implement_summary, review_round, ...
# 然后 spawn-codex.sh ... --prompt "$FIX_PROMPT" --log "$ROOT/.vmap/codex-implement-loop/logs/$TASK_ID-fix-r$ROUND.log" --timeout 3600
```

完成后回 §7 跑 review round +1。

### 8.1 为什么有上限（默认 3 轮）

上限不是品味，是**防 codex 在同一 finding 上无界打转烧 token**。撞到上限 = 强制把卡点 surface 出来交给人决策，比让 codex 再磨 5 轮强。

```bash
vmap update "$TASK_ID" --status blocked \
  --notes "codex-loop:review-cap: $ROUND rounds, last verdict=rework; see .vmap/codex-implement-loop/reviews/$TASK_ID-review-r$ROUND.md"
```

## 9. Blocked notes 前缀约定（强制）

vmap 只有 `blocked` 一个非完成态。codex loop 复用它表达多种含义，靠 notes 前缀区分：

| 前缀 | 含义 | 谁解 |
|---|---|---|
| `codex-loop:design-needed:` | 任务需要架构 / 产品决策才能继续 | 人 |
| `codex-loop:review-cap:` | 撞到 rework 轮数上限 | 人 / 调 prompt 后 controller 重派 |
| `codex-loop:codex-crash:` | codex 连续 2 轮没产生 diff 或 marker | controller 排查 + 重派 |
| `codex-loop:conflict:` | review findings 互斥 | 人 |
| `codex-loop:human-decision:` | fix codex 标 (E) 类——超出权限 | 人 |
| `codex-loop:dag-drift:` | 实施中发现 DAG 漂了 | 切维护模式 |

`vmap list tasks --status blocked --json | jq '.[] | select(.notes | startswith("codex-loop:"))'` 一眼分类。

## 10. 落地策略

开始前定一种，写进 resume state：

- `local-merge`：本地开发最常用。controller 在主 worktree `git merge --no-ff` cluster 分支，保留最终 diff。
- `branch-only`：只留下分支和 worktree，让用户自己看。
- `github-pr`：如果 `gh` 已登录，controller push 分支并开 PR；PR body 链接 vmap task、summary、review 报告、测试结果。

无论哪种，controller 负责 commit / push / PR，Codex 子进程不做。

落地成功后：

```bash
vmap update "$TASK_ID" --status done \
  --add-doc ".vmap/codex-implement-loop/runs/$TASK_ID-implement-summary.md" \
  --add-doc ".vmap/codex-implement-loop/prompts/$TASK_ID-implement.md" \
  --notes "codex-loop:done: round=$ROUND; implemented by codex-goal-implement-loop"
```

补上新测试路径：

```bash
vmap update "$TASK_ID" --add-test <new-or-run-test-path>
```

最后看 goal：

```bash
vmap show <goal-id>
vmap status --json
```

## 11. Worktree 生命周期

| 状态 | worktree 处理 |
|---|---|
| Codex `in-progress` | 创建 + 保留（codex 在写）|
| Codex `ok` 但还在 review | 保留 |
| 已落地（merged / pushed / PR opened） | `git worktree remove --force <wt>` + `git worktree prune` + `git branch -D <branch>` |
| `blocked` / `rework` 超上限 | **保留**供人审查；vmap notes 写明 wt 路径 |
| 多 task 串行做 | 上一个 task done 后必清理，否则下一轮 audit / grep 会被 stale code 污染 |

每个 loop 开始前 controller 自检：

```bash
git worktree list
# 应该只剩 main / 其它 in-flight cluster；多余的 stale wt 全删
```

## 12. Crash 恢复 / 幂等

每次 controller 进 turn 假设自己刚醒（应对 /clear、宿主重启、session 中断）：

```bash
# 1. 哪些 task 自己声称在跑
vmap list tasks --status in-progress --json | jq -r '.[] | select(.notes | startswith("codex-loop:")) | .id'

# 2. 真在跑的 codex 进程
ps -ef | grep -E "codex exec|spawn-codex" | grep -v grep

# 3. 最近的 log
ls -lt .vmap/codex-implement-loop/logs/ | head -10

# 4. 现有 worktree + 分支
git worktree list

# 5. 已开过的 PR（如果用 github-pr 模式）
gh pr list --head "vmap/*" --state open --json number,headRefName 2>/dev/null
```

### 12.1 判定状态

| 信号 | 状态 | 动作 |
|---|---|---|
| in-progress + ps 有 codex + log 无 done marker | 真在跑 | end turn，等 task-notification 或 wakeup |
| in-progress + ps 无 codex + log 末有 `VMAP_CODEX_IMPLEMENT_DONE:.*:ok` | 跑完没验收 | §6 走验收流程 |
| in-progress + ps 无 codex + log 末无 marker（被 kill / OOM） | 崩溃 | §12.2 重派 |
| blocked + notes `codex-loop:review-cap:` | 等人决策 | 不动 |
| done + 有 wt + 有分支 | 还没清理 | §11 worktree remove |

### 12.2 重派 implement / fix codex

崩溃重派时，**复用同一 worktree + 同一分支**（不要 `git worktree add` 重建），在 prompt 头部加 `resume_header`：

```
==== RESUME NOTICE ====
上一轮你（implement codex）在 worktree {{worktree_path}} 跑到一半被中断（log 末无 DONE marker）。
当前 worktree 工作区已经保留你上一轮的改动：

  git -C {{worktree_path}} status --short
  <controller 把当前状态贴这里>

继续完成 task。不要从头开始，不要把已经写好的代码删掉重写。
最后必须打印 VMAP_CODEX_IMPLEMENT_DONE:{{task_id}}:<status> marker。
==== END RESUME NOTICE ====

<原 prompt 内容>
```

### 12.3 PR / worktree 幂等

```bash
# PR 已存在则复用
if [[ "$LANDING" == "github-pr" ]]; then
  EXISTING=$(gh pr list --head "$BRANCH" --base "$BASE_BRANCH" --state open --json number --jq '.[0].number')
  PR_NUM=${EXISTING:-$(gh pr create --base "$BASE_BRANCH" --head "$BRANCH" --title "..." --body "...")}
fi

# worktree 已存在则复用
if ! git worktree list | grep -q " $WT "; then
  git worktree add -b "$BRANCH" "$WT" HEAD
fi
```

## 13. 什么时候停下来

遇到这些情况不要硬跑，告知用户切回普通模式：

- task 没有验收线索，docs/tests 都空
- AGENTS.md / CLAUDE.md 和用户需求冲突
- Codex 连续两次没有产生 diff 或 marker（标 `codex-loop:codex-crash:`）
- review 指出设计层问题，不是局部修补能解决
- 需要新增用户可感知能力，但 DAG 里没有对应 goal（标 `codex-loop:dag-drift:`，切维护模式）

无人值守的边界是 controller 能机器化判断；判断不了的就 surface 出来。
