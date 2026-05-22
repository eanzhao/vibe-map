# Codex prompt — architecture audit

> Template. Required vars: `{{iteration}}` `{{repo_root}}` `{{rules_path}}` `{{audit_md_path}}` `{{audit_ndjson_path}}` `{{rules_content_dump}}` `{{architecture_docs_dump}}` `{{guard_scripts_dump}}` `{{vmap_status_dump}}` `{{prior_iter_summary}}`.

---

你是 vibe-map codex-architecture-refactor-loop 的**审计 codex**，**iter {{iteration}}**。**只做分析、不改代码**。

## 必读

1. **架构规则文件**（controller 已经在派你之前 regenerate 过）：

   `{{rules_path}}` 内容：

   ```
   {{rules_content_dump}}
   ```

   每条规则形如 `RULE arch-NNN` + `source:` + `level: must/should/never` + `summary:` + `detect:`。所有违例都必须能引用其中一条 `rule_id`。

2. **架构文档原文**（rules.md 摘录后，对照原文做精读）：

   ```
   {{architecture_docs_dump}}
   ```

3. **现有 CI guard / 测试入口**（已经被覆盖的规则不重复报）：

   ```
   {{guard_scripts_dump}}
   ```

4. **vmap 当前状态**（避免重复开 task）：

   ```
   {{vmap_status_dump}}
   ```

5. **上一轮 audit summary**（如果 `{{iteration}} > 1`）：

   ```
   {{prior_iter_summary}}
   ```

   **不要把上一轮已经标记 `clusters_done` 的违例再报**。

## Worktree 卫生（强制 pre-audit 自检）

`find` / `rg` / `grep` 默认无视 git boundary，会扫到 sibling worktree（例如 `.vmap/codex-*-loop/worktrees/<other-cluster>`）里 pre-refactor 的代码。把那些当现状会出 bogus evidence。

派你之前 controller 应该已经清理过 stale worktree。你自己也再防御一道：

```bash
git -C {{repo_root}} worktree list
```

**任何 evidence file:line，必须先用 `git -C {{repo_root}} ls-files -- <path>` 验证文件在主仓库里存在**。
不在主仓库（只在 stale worktree）→ 视为污染，**不要写进 cluster**。

如果你扫到的违例只存在于 `.vmap/codex-*-loop/worktrees/...`，**禁止**把这种当 cluster evidence。

## 任务

找出违反 `{{rules_path}}` 规则的具体代码证据，按"可独立修改的 cluster"分组。

### 每个 cluster 必须有

- `id`：稳定字符串（如 `arch-cluster-001`），同 audit iter 内不重复
- `title`：一行人能读懂的描述
- `rule_id`：引用 `{{rules_path}}` 中的一条 `RULE arch-NNN`
- `severity`：`high` / `medium` / `low`
- `evidence`：≥ 1 条 `path:line — <实际代码片段>`，每条都已经过 `git ls-files` 验证存在
- `scope_paths`：实施该 cluster 时**会动的**文件 / 目录（用于 controller 分批 + worktree 隔离）
- `deps`：依赖的其它 cluster id（如果 cluster B 没 cluster A 不能编译就 `deps: ["arch-cluster-A"]`；soft-dep 不写）
- `risk`：`low` / `medium` / `high`（破 build / 跨模块多 / 改公开 API 都是 high）
- `requires_design`：`true` / `false`。需要产品 / 架构决策（不只是机械重构）的标 `true`
- `suggested_tests`：≥ 1 条已有测试 / guard 命令，或写"需要新增 <module>_test.<ext>"
- `summary`：3-5 行 "旧模式 / 新原则 / 怎么改"

### Cluster 边界判断

两个违例**可以**合成一个 cluster 当且仅当：
- 同一 `rule_id`，或
- 改动同一个文件 / 紧邻模块，或
- 有 hard-dep（A 不改 B 也改不动）

否则**拆开**——controller 才能并行。

## 输出

### 1. Markdown 报告 `{{audit_md_path}}`

```markdown
---
schema: vmap-codex-arch-audit-v1
iteration: {{iteration}}
audited_at: <ISO8601 UTC>
cluster_count: <N>
worktree_validated: true
---

# Architecture audit iter {{iteration}}

## Coverage manifest

- 扫描 rule_ids: <逐一列出>
- 跳过的规则（已被 guard 覆盖 / 上一轮处理完）: <列出原因>
- 扫描命令：<列你跑过的 rg / grep / 自定义脚本>
- 扫描的目录：<scope 总览>

## Clusters

### arch-cluster-001 — <title>
- rule_id: arch-001
- severity: high | medium | low
- risk: low | medium | high
- requires_design: false
- deps: []
- scope_paths:
  - src/foo/bar.ts
  - src/foo/baz.ts
- evidence:
  - `src/foo/bar.ts:42 — function shouldX() { ... }`（违反 rule arch-001 "..."）
  - `src/foo/baz.ts:88 — return shouldX(...)`
- suggested_tests:
  - src/foo/bar_test.ts (existing)
  - 新增 src/foo/baz_test.ts 覆盖 X 路径
- summary: |
    Old: <旧模式一句话，必要时引用规则原文>
    New: <新原则一句话>
    Fix: <怎么改，2-3 句>

### arch-cluster-002 — ...
...

## Rejected candidates (false positives) — sample

按规则 grep 命中但**不**算违例的样本（说明你做了过滤，不是糊弄数量）：

- `src/legacy/old.ts:10` — 规则 arch-002 允许 legacy 标注，已查到该文件有 `// legacy: ...` 注释
- ...
```

### 2. NDJSON `{{audit_ndjson_path}}`

每行一个 cluster（一行一 JSON 对象，**不要**多行 JSON），controller 用 `jq` 切片：

```json
{"id":"arch-cluster-001","title":"...","rule_id":"arch-001","severity":"high","risk":"medium","requires_design":false,"deps":[],"scope_paths":["src/foo/bar.ts","src/foo/baz.ts"],"evidence":["src/foo/bar.ts:42 ...","src/foo/baz.ts:88 ..."],"suggested_tests":["src/foo/bar_test.ts","new:src/foo/baz_test.ts"],"summary":"Old: ...\nNew: ...\nFix: ..."}
```

字段名与 markdown 一致。

## 反过来——什么时候报 INCOMPLETE

- 任一规则你说"扫了但没违例"却**没**给具体扫描命令 / 计数 → INCOMPLETE
- evidence 引用的 `path:line` 在 `git ls-files` 中找不到（stale worktree 污染）→ INCOMPLETE
- 所有 cluster 都 `requires_design: true`（说明 audit 没分级，全推给设计）→ INCOMPLETE
- markdown 或 NDJSON 缺一 → INCOMPLETE

这种情况下打印：

```
VMAP_CODEX_ARCH_AUDIT_INCOMPLETE:iter-{{iteration}}:<reason>
```

否则末行打印：

```
VMAP_CODEX_ARCH_AUDIT_DONE:iter-{{iteration}}:<cluster-count>
```

## 红线

- 只读不写源代码。唯一可写文件：`{{audit_md_path}}` + `{{audit_ndjson_path}}`。
- 禁止跑 `vmap update *` —— controller 把 cluster 转 vmap task。
- 禁止凭"代码看起来不优雅"开 cluster；每条都必须能引用一条 `rule_id`。
- 禁止把现有 CI guard 已经覆盖的规则再报（写在 Coverage manifest "跳过的规则"里）。
- 禁止把 stale worktree evidence 写进 cluster。
- 禁止安装新依赖。

开始 audit。
