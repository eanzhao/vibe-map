# Codex Architecture Refactor Loop

适用场景：用户希望 agent 调用 Codex CLI，按 `AGENTS.md` / `CLAUDE.md` / 架构文档里写好的原则，持续审计并重构代码，而不是只修一个具体功能点。

这份 playbook 把架构原则蒸馏成机器可读的 `rules.md`，让 Codex 按它审计违例、写回 vmap task、循环 implement / review / verify。用户能在 `.vmap/vibe-map.html` 看到哪些架构债已处理、哪些还卡着。

支撑文件都在 `~/.vmap/skills/playbooks/codex-loops/`：

- `prompts/arch-rules-generate.md` — 蒸馏 / 刷新 rules.md
- `prompts/arch-audit.md` — audit codex 模板
- `prompts/arch-implement.md` — implement codex 模板
- `prompts/arch-review.md` — reviewer codex 模板（anti-sycophancy）
- `scripts/spawn-codex.sh` — codex exec 包装

> 这份只处理"按架构原则反复重构"。如果用户只是想用 codex 做一个具体 task 的实现，看 `codex-goal-implement-loop.md`。
> 两份共享 `0`、`0.5`、`5`、`9`、`11`、`12` 这些约定（worktree 纪律 / blocked notes 前缀 / crash 恢复 / 后台任务模式），那边写得更详细，这边只写**架构 refactor 特有**的部分。

## 0. Controller 原则

- Controller 不亲手改 production code；它派 `codex exec` 做 audit / rules-generate / implement / review。
- 架构规则来自项目文件，不来自 controller 的口味。优先读 `AGENTS.md`、`CLAUDE.md`、目录内更近的 AGENTS、`docs/architecture*`、`docs/canon/`、CI guard 脚本。
- 每个架构问题都必须能指向规则来源和代码证据。**不能只写"看起来不优雅"**。
- vmap 是状态面。每个 cluster 都要变成 task，或者明确写成 blocked/design-needed。
- state 文件只做恢复辅助；事实源是 vmap、git diff、log marker、测试/CI、PR 状态。
- **路径纪律**：worktree 当 cwd 时 `.vmap` 会解析到子 worktree。所有给 codex 的 prompt 里 `.vmap/...` artifact 路径**必须是绝对路径**。
- **vmap notes 约定**：所有 codex loop 写进 task notes 的状态都以 `codex-loop:` 开头（详见 `codex-goal-implement-loop.md` §9）。

## 0.5 预检（每个 loop 开始一次）

```bash
command -v codex >/dev/null || { echo "请装 Codex CLI: https://github.com/openai/codex"; exit 1; }
ls ~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh
test -f .vmap/vibe-map.json || { echo "先 vmap init"; exit 1; }
```

成本提醒：一轮 audit + 3 个 cluster 的 implement + review 通常 3-6 小时 wall + 几十万 token。先在小范围跑一轮（限 `--scope-paths` 到一个模块），验 rules.md 与 audit 质量，再放跑全仓库。

## 1. 建或复用架构 goal

如果项目还没有架构对齐 goal：

```bash
vmap add goal --id g-architecture-alignment \
  --title "代码持续符合项目架构原则" \
  --closure obligation \
  --owner ai \
  --focus \
  --docs AGENTS.md
```

如果项目用 `CLAUDE.md` 或其它架构文档：

```bash
vmap update g-architecture-alignment --add-doc CLAUDE.md
vmap update g-architecture-alignment --add-doc docs/architecture.md
```

已有类似 goal 就复用，不要重复建。

## 2. 建 loop 目录 + 命名约定

```bash
ROOT="$(pwd)"
mkdir -p "$ROOT/.vmap/codex-refactor-loop/"{logs,runs,prompts,reviews,worktrees,clusters,state}
```

命名约定（每个 cluster + 每轮 audit）：

```
prompts/
  rules-generate-iter<N>.md
  audit-iter<N>.md
  <cluster-id>-implement.md
  <cluster-id>-fix-r<R>.md
  <cluster-id>-review-r<R>.md
logs/
  rules-generate-iter<N>.log
  audit-iter<N>.log
  <cluster-id>-implement.log
  <cluster-id>-fix-r<R>.log
  <cluster-id>-review-r<R>.log
runs/
  audit-iter<N>.md
  audit-iter<N>-clusters.ndjson
  <cluster-id>-implement-summary.md
  <cluster-id>-fix-r<R>-summary.md
reviews/
  <cluster-id>-review-r<R>.md
worktrees/
  <cluster-id>/
state/
  iter<N>.json                          # debug 用，不参与决策
```

## 3. 蒸馏 / 刷新 rules.md（每轮 audit 前必跑）

`.vmap/codex-refactor-loop/rules.md` 是 audit 的输入。**架构文档每变一次，就要重新生成 rules.md**，否则 audit 会拿 stale 规则误判。

### 3.1 判断是否需要重生成

```bash
PRIOR_RULES=".vmap/codex-refactor-loop/rules.md"
# 列出所有架构文档 + 上次 rules.md 生成后被修改过的
docs="AGENTS.md CLAUDE.md docs/architecture.md docs/canon/*.md"
ls $docs 2>/dev/null

# 上次 rules.md 之后有没有架构文档被改
if [[ ! -f "$PRIOR_RULES" ]]; then
  NEEDS_REGEN=1   # 首次
else
  NEEDS_REGEN=0
  for doc in $docs; do
    [[ -f "$doc" ]] || continue
    if [[ "$doc" -nt "$PRIOR_RULES" ]]; then
      NEEDS_REGEN=1
      break
    fi
  done
fi
```

### 3.2 派 rules-generate codex

```bash
ITER=1
RULES_PROMPT="$ROOT/.vmap/codex-refactor-loop/prompts/rules-generate-iter$ITER.md"
RULES_LOG="$ROOT/.vmap/codex-refactor-loop/logs/rules-generate-iter$ITER.log"
RULES_OUT="$ROOT/.vmap/codex-refactor-loop/rules.md"

# materialize from ~/.vmap/skills/playbooks/codex-loops/prompts/arch-rules-generate.md
# 必填: rules_path, architecture_doc_paths, prior_rules_path, guard_scripts_dump

~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh \
  --cd "$ROOT" \
  --prompt "$RULES_PROMPT" \
  --log "$RULES_LOG" \
  --timeout 3600 \
  --sandbox workspace-write
```

Codex 写出新 rules.md，末尾打印 `VMAP_CODEX_RULES_REGENERATED:<count>:<changed|unchanged|initial>`。

把 rules.md 挂回 vmap：

```bash
vmap update g-architecture-alignment --add-doc .vmap/codex-refactor-loop/rules.md
```

### 3.3 rules.md 字段语义

每条 RULE 有 `level: must/should/never` + `enforced-by: <guard-or-none>`：

- `level: must` —— 任何违例都自动开 cluster
- `level: should` —— 抓 + 提示，可在 implement summary "Deviations" 节解释
- `level: never` —— 禁止模式，任何引入 = blocking
- `enforced-by: <guard>` —— CI 已守住，audit 会标 `skip:already-enforced`，不重复开 cluster

## 4. Audit codex

### 4.1 Worktree 卫生（强制 pre-audit cleanup）

audit codex 用 `find` / `rg` 扫描，**无视 git boundary 会扫到 sibling worktree**（已 merge 但未清理的 wt 里仍保留 pre-refactor 代码）。把那些当现状会出 bogus evidence——cluster 指向 main 中早已删除的文件。

派 audit 前 controller 必跑：

```bash
git worktree list
# 对每个非 main / 非 active wt：
#   - 对应 PR 已 merged → 删
#   - 对应 PR 已 closed → 删
#   - 对应 branch 已不在 origin → 删
for wt in <stale-worktrees>; do
  git worktree remove --force "$wt"
done
git worktree prune
# 验收: git worktree list 只剩 main + 当前 in-flight cluster wt
```

### 4.2 派 audit codex

```bash
ITER=1
AUDIT_PROMPT="$ROOT/.vmap/codex-refactor-loop/prompts/audit-iter$ITER.md"
AUDIT_LOG="$ROOT/.vmap/codex-refactor-loop/logs/audit-iter$ITER.log"
AUDIT_MD="$ROOT/.vmap/codex-refactor-loop/runs/audit-iter$ITER.md"
AUDIT_NDJSON="$ROOT/.vmap/codex-refactor-loop/runs/audit-iter$ITER-clusters.ndjson"

# materialize from ~/.vmap/skills/playbooks/codex-loops/prompts/arch-audit.md
# 必填: iteration, repo_root, rules_path, audit_md_path, audit_ndjson_path,
#       rules_content_dump, architecture_docs_dump, guard_scripts_dump,
#       vmap_status_dump, prior_iter_summary

~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh \
  --cd "$ROOT" \
  --prompt "$AUDIT_PROMPT" \
  --log "$AUDIT_LOG" \
  --timeout 5400 \
  --sandbox workspace-write
```

### 4.3 Controller 验收 audit

- log 末尾有 `VMAP_CODEX_ARCH_AUDIT_DONE:iter-N:<count>`（INCOMPLETE 视为失败，重派）
- markdown 和 NDJSON 都存在
- 每个 cluster 有 `rule_id`、evidence、scope_paths、suggested_tests
- 抽 3 个 evidence 用 `git ls-files` 验证文件真存在（不是 stale wt 污染）
- `requires_design=true` 的 cluster 没有被自动列入实施批次

抽查脚本：

```bash
jq -r '.evidence[]?' "$AUDIT_NDJSON" | head -10 | while read -r ev; do
  path=$(echo "$ev" | cut -d: -f1)
  git ls-files --error-unmatch "$path" >/dev/null 2>&1 \
    && echo "OK: $path" \
    || echo "MISSING (stale-wt suspect): $path"
done
```

## 5. 把 cluster 写成 vmap task

每个可自动处理的 cluster：

```bash
vmap add task --id t-arch-cluster-001 \
  --goal g-architecture-alignment \
  --title "<cluster title>" \
  --regression-testable \
  --docs ".vmap/codex-refactor-loop/runs/audit-iter1.md" \
  --notes "codex-loop:planned: rule=<rule_id>; scope=<scope_paths>; risk=<risk>"
```

补测试线索：

```bash
vmap update t-arch-cluster-001 --add-test <suggested-test-or-guard>
```

需要设计决策的 cluster（`requires_design=true`）：

```bash
vmap add task --id t-arch-cluster-00N \
  --goal g-architecture-alignment \
  --title "<cluster title>" \
  --docs ".vmap/codex-refactor-loop/runs/audit-iter1.md" \
  --notes "codex-loop:design-needed: rule=<rule_id>; <一句话决策点>"
vmap update t-arch-cluster-00N --status blocked
```

如果用 GitHub，同步开 issue 把 URL 加到 `docs`：

```bash
gh issue create --title "[arch-design] cluster-00N: ..." \
  --body "$(cat <<EOF
See .vmap/codex-refactor-loop/runs/audit-iter1.md cluster-00N.

决策需要:
- ...
EOF
)" --label "refactor-design-needed"
```

## 6. 分批（cluster 互不踩）

同一批里的 cluster 必须尽量互不踩：

- `scope_paths` 不重叠
- 不改同一个 package / project / module 边界
- 不改同一个 schema / proto / migration 文件
- `deps` 不互相引用

保守默认：一次最多 **3 个低/中风险** cluster 并行；高风险 cluster 单独跑。

## 7. Implement codex

每个 cluster 一个 worktree：

```bash
ITER=1
CID="arch-cluster-001"
WT="$ROOT/.vmap/codex-refactor-loop/worktrees/$CID"
BRANCH="vmap/arch-iter$ITER-$CID"

git worktree add -b "$BRANCH" "$WT" HEAD

vmap update "t-$CID" --status in-progress \
  --notes "codex-loop:running: implement; log=.vmap/codex-refactor-loop/logs/$CID-implement.log; worktree=$WT"
```

材料化 prompt（`~/.vmap/skills/playbooks/codex-loops/prompts/arch-implement.md`）。必填变量：`cluster_id`、`iteration`、`worktree_path`、`branch`、`repo_root`、`old_pattern`、`new_principle`、`rule_id`、`scope_paths`（列表）、`verification_hints`、`summary_output_path`、`rules_dump`、`audit_cluster_dump`（NDJSON 中本 cluster 那一行）、`build_commands`、`test_commands`、`guard_commands`、`resume_header`。

派出：

```bash
~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh \
  --cd "$WT" --add-dir "$ROOT" \
  --prompt "$ROOT/.vmap/codex-refactor-loop/prompts/$CID-implement.md" \
  --log "$ROOT/.vmap/codex-refactor-loop/logs/$CID-implement.log" \
  --timeout 5400 \
  --sandbox workspace-write
```

**后台模式**：Claude Code / 支持 `task-notification` 的宿主用 Bash `run_in_background: true` 派；codex 退出自动唤醒。同 turn 内 `ScheduleWakeup` 排 30 分钟 fallback。**禁止**同步等 60-90 min。详见 `codex-goal-implement-loop.md` §5.1。

## 8. Review codex（独立 verify）

每个 implement 完成后做独立 review。优先派完整 reviewer codex（`prompts/arch-review.md`）而不是 `codex exec review`——后者偏 sycophancy，borderline pass 会把违例当 done。

```bash
ROUND=1
REVIEW_OUT="$ROOT/.vmap/codex-refactor-loop/reviews/$CID-review-r$ROUND.md"

# materialize from arch-review.md
# 必填: cluster_id, iteration, worktree_path, branch, review_round,
#       review_output_path, implement_summary_path, rule_id,
#       rules_dump, audit_cluster_dump, anti_pattern_grep_table, prior_rounds_dump

~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh \
  --cd "$WT" --add-dir "$ROOT" \
  --prompt "$ROOT/.vmap/codex-refactor-loop/prompts/$CID-review-r$ROUND.md" \
  --log "$ROOT/.vmap/codex-refactor-loop/logs/$CID-review-r$ROUND.log" \
  --timeout 3600
```

`anti_pattern_grep_table` 由 controller 从 rules.md 抽：每条 `level: never` 或 `level: must` 的规则的 `detect:` 字段拼成一行 grep 提示。

Controller 再跑测试 / guard / vmap 自检：

```bash
cd "$WT"
<test_commands>          # 项目实际命令；如 moon test / dotnet test / pytest / cargo test / npm test
<guard_commands>         # 如 moon check / dotnet ci/scripts
cd "$ROOT"
vmap audit               # 防 codex 改了源代码但 task docs/tests 没跟上
vmap doctor              # 整体健康
vmap coverage            # codex 改的代码是否在某 task docs 中
```

任一 vmap 报红 → 视为 **rework**（不是 codex 错了，是 vmap 状态没跟上）；先 `vmap update --add-test/--add-doc` 补，再决定是否真要 rework codex。

## 9. 通过 / 返工 / 终止

通过条件：

- review verdict = `pass`
- 相关测试通过
- 没有新增 vmap audit 违例
- diff 没超出 cluster scope，或 summary 解释了必要性

**rework** 时最多回 implement **2 轮**（refactor loop 比 goal-implement loop 上限更紧——因为重构本来就该小步快）。每轮材料化 `prompts/goal-fix.md`（goal-fix 是通用的，无需 arch-specific 版本；它按 review F<N> 分类 ABCDE 处理）：

```bash
FIX_PROMPT="$ROOT/.vmap/codex-refactor-loop/prompts/$CID-fix-r$ROUND.md"
~/.vmap/skills/playbooks/codex-loops/scripts/spawn-codex.sh \
  --cd "$WT" --add-dir "$ROOT" \
  --prompt "$FIX_PROMPT" \
  --log "$ROOT/.vmap/codex-refactor-loop/logs/$CID-fix-r$ROUND.log" \
  --timeout 3600
```

### 9.1 为什么 rework 上限是 2

上限不是品味，是**防 codex 在同一 finding 上无界打转烧 token**。撞到上限 = 强制把卡点 surface 出来：要么规则需要重写（rules.md），要么 cluster 拆得不对（要拆成多个或合并），要么真的需要设计决策。**让 codex 再磨 5 轮通常不能让重构变对，但能让 token 单变贵**。

撞到上限：

```bash
vmap update "t-$CID" --status blocked \
  --notes "codex-loop:review-cap: $ROUND rounds; last verdict=rework; see .vmap/codex-refactor-loop/reviews/$CID-review-r$ROUND.md"
```

`abort` verdict 直接：

```bash
vmap update "t-$CID" --status blocked \
  --notes "codex-loop:human-decision: review abort; see .vmap/codex-refactor-loop/reviews/$CID-review-r$ROUND.md"
```

## 10. 落地和回写

落地策略和 goal-implement loop 一样：`local-merge` / `branch-only` / `github-pr` 三选一。controller 负责 git 操作。

落地后：

```bash
vmap update "t-$CID" --status done \
  --add-doc ".vmap/codex-refactor-loop/runs/$CID-implement-summary.md" \
  --add-doc ".vmap/codex-refactor-loop/reviews/$CID-review-r$ROUND.md" \
  --notes "codex-loop:done: rule=<rule_id> satisfied; tests passed; round=$ROUND"
```

清理 worktree（强制——防下一轮 audit 污染）：

```bash
git worktree remove --force "$WT"
git worktree prune
# 分支：local-merge 后已合并 → 可删；branch-only / github-pr 保留供人审查
```

一批都 done 后看 goal 进度：

```bash
vmap show g-architecture-alignment
vmap audit
vmap doctor
vmap coverage
```

## 11. Worktree 生命周期（强制）

| 状态 | worktree 处理 |
|---|---|
| Codex `in-progress` | 创建 + 保留 |
| review pass + 已落地 | `git worktree remove --force` + `git worktree prune` + `git branch -D` |
| `blocked` / `rework` 超上限 | 保留供人审查；vmap notes 写明 wt 路径 |
| `requires_design` | **不创建** worktree（cluster 还在 `blocked` 等设计） |
| 跨轮 audit 前 | **必清理** stale wt——否则 audit codex 会扫到 sibling wt 里的 pre-refactor 代码出 bogus evidence |

每个 loop 开始前 controller 自检：

```bash
git worktree list   # 只剩 main + 当前 in-flight cluster；多余的全删
```

事故记忆：iter22 audit 因为没清理 iter15 cluster-025 的 wt，把里面的 pre-refactor 代码当现状报，cluster-001 完全 bogus，浪费 5400s codex 时间。

## 12. Crash 恢复 / 幂等

进 turn 假设刚醒（应对 /clear、宿主重启、session 中断）。流程与 `codex-goal-implement-loop.md` §12 相同：

```bash
# 1. 哪些 task 自己声称在跑（按 vmap notes 前缀过滤）
vmap list tasks --status in-progress --json | jq -r '.[] | select(.notes | startswith("codex-loop:")) | .id'

# 2. 真在跑的 codex 进程
ps -ef | grep -E "codex exec|spawn-codex" | grep -v grep

# 3. 最近的 log（每个 cluster 看最新 round）
ls -lt .vmap/codex-refactor-loop/logs/ | head -20
tail -5 <log>   # 找 EXIT / DONE 标记

# 4. 现有 worktree + 分支
git worktree list

# 5. PR 状态（如果用 github-pr）
gh pr list --head "vmap/arch-iter*" --state open --json number,headRefName
```

崩溃重派时**复用** worktree + 分支，prompt 头部加 `resume_header`（复用 goal-implement.md / arch-implement.md 的模板）。

### 12.1 跨 audit 轮恢复

如果 controller 在 iter N 中途挂了（部分 cluster done、部分还没派），下次启动：

1. 列 `audit-iter$N-clusters.ndjson` 中所有 cluster id
2. `vmap list tasks --status done` 取已完成的
3. 差集 = 还没做的，按 §6 分批继续

**不要重派 audit codex**（audit 输出未变）。除非 rules.md 在中间被刷新过——那时 audit-iter$N 已经基于 stale rules，需要新建 iter$(N+1)。

## 13. 再审计

每轮落地后再跑 §3（rules-generate）+ §4（audit）：

- 没有新 cluster：把 goal 推进 closure，例如 `scoped` 或 `public`。
- 还有 cluster：新增下一轮 task，继续。
- 反复出现同一类问题：说明需要 guard。把"新增 guard/test"单独建 task，不要继续手修（这是 vibe-map 把 codex loop 绑回产品价值的地方——让 audit 推动 enforced-by 长大）。

```bash
vmap update g-architecture-alignment --closure scoped
```

**不要无限循环**。建议每次用户授权的无人值守窗口最多跑一个 audit iteration + 一批 implement；下一轮先汇报，让人确认方向。

## 14. 常见坑

- 把 `AGENTS.md` / `CLAUDE.md` 当建议而不是约束：错。架构 loop 的目的就是执行这些原则。
- audit 没证据就开 task：错。每个 task 要能追到 rule 和 path。
- 重构顺手改功能：错。功能变化应该走 `codex-goal-implement-loop.md`。
- 只在本地 log 写状态：错。vmap 必须同步更新，GitHub PR/issue 可用时也同步。
- Codex 没 marker 或没 summary 也算成功：错。视为失败或重派。
- rules.md 不刷新：错。架构文档变了 audit 拿 stale 规则，会出 false positive/negative。每轮必查（§3.1）。
- stale worktree 不清理：错。audit codex 会扫进去出 bogus evidence。每轮必查（§11）。
- 同步等 codex：错。后台跑（详见 goal-implement.md §5.1），不然 token 爆 + /clear 后丢追踪。
- rework 上限调到 10：错。上限是有道理的（§9.1），撞上限 = 让人决策，不是让 codex 再磨。
