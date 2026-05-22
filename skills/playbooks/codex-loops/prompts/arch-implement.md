# Codex prompt — implement one architecture refactor cluster

> Template. Required vars: `{{cluster_id}}` `{{iteration}}` `{{worktree_path}}` `{{branch}}` `{{repo_root}}` `{{old_pattern}}` `{{new_principle}}` `{{rule_id}}` `{{scope_paths}}` `{{verification_hints}}` `{{summary_output_path}}` `{{rules_dump}}` `{{audit_cluster_dump}}` `{{test_commands}}` `{{build_commands}}` `{{guard_commands}}` `{{resume_header}}`.

---

{{resume_header}}

你是 vibe-map codex-architecture-refactor-loop 的**实施 codex**。**只处理一个 cluster**，**不扩 scope**。

Cluster：`{{cluster_id}}`（iter {{iteration}}，rule `{{rule_id}}`）
工作目录：`{{worktree_path}}`（分支 `{{branch}}`）

## 必读

1. **架构规则全文**（不是只看 cluster 引用的那一条）：

   ```
   {{rules_dump}}
   ```

2. **本 cluster 的 audit 条目**：

   ```
   {{audit_cluster_dump}}
   ```

3. **旧模式 / 新原则**：

   - Old: {{old_pattern}}
   - New: {{new_principle}}

4. **本项目命令**（**优先用这些，不要凭印象**）：

   - 构建：`{{build_commands}}`
   - 测试：`{{test_commands}}`
   - 架构 / 测试 guard：`{{guard_commands}}`

## 硬约束

1. **作用域 = `{{scope_paths}}` 列出的文件 + 它们紧邻的测试**。扩出去前必须打印 `SCOPE_EXTEND: <file> <reason>`，reason 必须能映射回 cluster 描述或 `{{rule_id}}` 原文。
2. **不改变外部行为**——除非 cluster summary 明确允许。如果 cluster 描述的修复 inherently 改变行为，先打印 `BEHAVIOR_CHANGE: <短描述> <影响范围>` 再做。
3. **不新增功能**：不引入新接口 / 新 flag / 新模块。新增极小辅助类型须注释 `<lang-comment> Refactor helper, no behavior change`。
4. **代码注释**（被重构的每个关键类型 / 函数加 3-5 行）：

   ```
   <项目惯用注释语法> Refactor (iter{{iteration}}/{{cluster_id}}, {{rule_id}}):
   <项目惯用注释语法>   Old pattern: {{old_pattern}}
   <项目惯用注释语法>   New principle: {{new_principle}}
   ```

   纯机械迁移可以省。
5. **测试**：跑 `{{verification_hints}}` 列的测试（如果有）+ `{{test_commands}}`，必须全过。覆盖不够补测试；禁止 `sleep` / `Task.Delay` / `setTimeout` 当节奏（用 deterministic awaiter）。
6. **架构 guard**：跑 `{{guard_commands}}`，必须全过。其它 cluster-specific guard 见 `verification_hints` 附录。
7. **Git 拓扑由 controller 负责**：禁止 `git commit` / `git push` / `git checkout <branch>` / PR 操作。
8. **不安装新依赖**。
9. **不动外部仓库 / 父目录**。写权限只在 `{{worktree_path}}` + `{{summary_output_path}}`。

## 流程

1. 读 cluster audit、读 `scope_paths` 全部文件、读 `{{rules_dump}}` 中本 `{{rule_id}}` 的原文。
2. 打印 `PLAN:` 多行实施动作。
3. 实施改动。
4. 跑 `{{build_commands}}`。失败修复，最多 5 次。
5. 跑测试（`{{verification_hints}}` + `{{test_commands}}`）。失败修复（**禁止** disable/skip），最多 5 次。
6. 跑 `{{guard_commands}}`。失败修复。
7. `git -C {{worktree_path}} add -A && git -C {{worktree_path}} status --short`。**不要 commit**。
8. 写 summary 到 **绝对路径** `{{summary_output_path}}`：

   ```markdown
   ---
   schema: vmap-codex-arch-implement-v1
   cluster_id: {{cluster_id}}
   iteration: {{iteration}}
   rule_id: {{rule_id}}
   branch: {{branch}}
   worktree: {{worktree_path}}
   implemented_at: <ISO8601 UTC>
   ---

   ## Old pattern → New principle
   - Old: {{old_pattern}}
   - New: {{new_principle}}

   ## Files changed
   - path/to/file (+N -M)

   ## Test runs
   ```bash
   <你跑过的命令>
   ```
   - 结果：<N passed, 0 failed>

   ## Build / guard runs
   - {{build_commands}} — pass / fail+原因
   - {{guard_commands}} — pass / fail+原因

   ## Behavior preservation
   <一段：本 refactor 是否改变外部行为；如果改了，BEHAVIOR_CHANGE 记录 + 影响范围>

   ## SCOPE_EXTEND records
   <每条 SCOPE_EXTEND 一行，含 file + reason>

   ## Deviations / blockers
   <如果偏离了 cluster 描述或卡住，写为什么>

   ## Follow-up clusters (optional)
   <如果发现需要另开 cluster，写在这里，controller 决定是否加入下一轮 audit>
   ```

9. **最末一行**打印：

   ```
   VMAP_CODEX_ARCH_IMPLEMENT_DONE:{{cluster_id}}:<status>
   ```

   `<status>` ∈ {`ok`, `partial`, `blocked`}。

## 红线

- 禁止改 `{{scope_paths}}` + `{{summary_output_path}}` 之外的任何文件（SCOPE_EXTEND 是协议层声明，不是免责）。
- 禁止 `git commit` / `git push` / `git checkout` / `git rebase`/ PR 操作。
- 禁止顺手重构无关代码。
- 禁止 disable / skip 测试。
- 禁止安装新依赖。
- 禁止改 vmap JSON / 跑 `vmap update *`。
- 禁止跨 worktree 读写。

开始执行。
