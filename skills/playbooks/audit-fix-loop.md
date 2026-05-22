# Playbook — audit-driven fix loop

> 用 `vmap audit` 让 AI 自己把测试 / 文档 / region metadata 补齐。

如果用户要的是“按 AGENTS.md / CLAUDE.md 找架构违例并让 Codex CLI 持续重构”，读 `skills/playbooks/codex-architecture-refactor-loop.md`。这份只处理 vmap 自身 audit 报出的 metadata / docs / tests 缺口。

## 工作流

```bash
while true; do
  vmap audit --json > /tmp/audit.json
  code=$?
  if [ $code -eq 0 ]; then
    echo "audit clean, done"
    break
  fi
  # parse violations, fix each one, then vmap update
done
```

## violation 类型 → 修法

vmap 当前 audit 规则：

### `missing_tests`

含义：goal/task `regression_testable: true` 但 `tests: []`。

修法：

1. 找到对应代码：`vmap show <id>` 看 `docs:` 列表里有哪些源文件被引用。
2. 写测试文件 `src/xxx/yyy_test.mbt`（或对应语言惯例）
3. 关联回 vmap：
   ```bash
   vmap update <id> --add-test src/xxx/yyy_test.mbt
   ```

如果这个 goal/task 其实**不需要回归测试**（比如纯文档 goal、设计探索 goal），改字段：

```bash
vmap update <id> --no-regression-testable
```

### `missing_docs`

含义：goal/task `status != todo` 但 `docs: []`。

修法：

1. 写文档（README 段、`docs/feature.md`、ADR / RFC）
2. 关联回 vmap：
   ```bash
   vmap update <id> --add-doc docs/auth.md
   vmap update <id> --add-doc src/auth/README.md
   ```

**docs 不只是文档文件**——`src/auth/middleware.mbt` 这种"自带 doc-comment 的源文件"也算（vmap 不区分）。任何"读了能理解这个 goal/task 在做什么"的文件都可以放进去。

### `missing_region_metadata`

含义：goal 缺一个或多个 region 字段（`closure` / `formal` / `product` / `owner` / `issue_count` / `focus` / `archived` / `promoted_at` / `gh_query`）。

修法：批量 update：

```bash
vmap update <goal-id> \
  --closure scoped \
  --formal checked \
  --product default \
  --owner alice \
  --issue-count 1 \
  --gh-query "is:issue label:<goal-id>"
```

`promoted_at` 至少要有一条：

```bash
vmap update <goal-id> --promoted-at obligation=2026-05-19
```

（vmap audit 检查的是字段非空，不检查内容的合理性。）

## AI loop 的 shell 模板

```bash
#!/bin/bash
# Save as scripts/audit-loop.sh
set -euo pipefail

MAX_ITER=10
for i in $(seq 1 $MAX_ITER); do
  echo "=== iteration $i ==="
  if vmap audit --json > /tmp/violations.json; then
    echo "clean ✓"
    exit 0
  fi
  echo "violations:"
  python3 -c "
import json
v = json.load(open('/tmp/violations.json'))['violations']
for x in v[:10]:
    print(f\"  {x['node_kind']:5s} {x['node_id']:30s} {x['kind']:25s} {x['message']}\")"
  # ... agent now reads violations and makes fixes ...
  # ... e.g., write tests, write docs, vmap update --add-test/--add-doc/...
  read -p "press enter after fixing this batch..."
done

echo "max iterations reached, still has violations"
exit 3
```

## 实战例子

```bash
$ vmap audit --json
{
  "ok": false,
  "violations": [
    {
      "kind": "missing_tests",
      "node_id": "goal-auth",
      "node_kind": "goal",
      "message": "goal is regression-testable but has no `tests` entries"
    },
    {
      "kind": "missing_docs",
      "node_id": "t-oauth-callback",
      "node_kind": "task",
      "message": "task is past `todo` but has no `docs` entries"
    },
    {
      "kind": "missing_region_metadata",
      "node_id": "goal-auth",
      "node_kind": "goal",
      "message": "goal missing required field: gh_query"
    }
  ]
}

# 修 missing_tests
$ ls src/auth/*_test.mbt
src/auth/oauth_test.mbt
$ vmap update goal-auth --add-test src/auth/oauth_test.mbt

# 修 missing_docs
$ vmap update t-oauth-callback --add-doc src/auth/callback.mbt

# 修 missing_region_metadata
$ vmap update goal-auth --gh-query "is:issue label:goal-auth"

# 再 audit
$ vmap audit
audit: clean (0 violations)
$ echo $?
0
```

## 配套：GitHub issue 数漂移

`vmap audit` 不查 GitHub issue 数对不对，要跑：

```bash
python3 tools/audit_github.py --file .vmap/vibe-map.json
python3 tools/audit_github.py --file .vmap/vibe-map.json --strict       # 任何漂移 = exit 1
python3 tools/audit_github.py --file .vmap/vibe-map.json --markdown     # 适合 PR 评论
```

依赖 `gh` CLI，确认用户已登录。
