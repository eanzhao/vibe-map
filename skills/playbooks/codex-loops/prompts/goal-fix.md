# Codex prompt — fix review findings on a vmap task

> Template. Required vars: `{{task_id}}` `{{task_title}}` `{{worktree_path}}` `{{branch}}` `{{review_round}}` `{{review_report_path}}` `{{prior_implement_summary}}` `{{fix_summary_path}}` `{{test_commands}}` `{{build_commands}}` `{{guard_commands}}` `{{resume_header}}`.

---

{{resume_header}}

你是 Codex 子进程，**只修上一轮 review 报告里的 findings，不扩 scope**。worktree 是上一轮 implement codex 的同一个，分支同名，工作区保留前一轮改动。

任务：`{{task_id}}` — {{task_title}}
Round：{{review_round}}
工作目录：`{{worktree_path}}`（分支 `{{branch}}`）

## 必读（按顺序）

1. **Review 报告**（你被派的原因）：`{{review_report_path}}`。每个 `F<N>` finding 必须逐条响应——要么修，要么写明 reject 理由。
2. **上一轮 implement summary**：`{{prior_implement_summary}}`。
3. **历史轮 review + fix**（如果 `{{review_round}} > 1`）：同目录下 `*-review-r<N>.md` / `*-fix-r<N>.md`，**不要把上一轮已经驳回过的"修复"再交一次**。
4. **当前 worktree diff**：

   ```bash
   git -C {{worktree_path}} diff --stat
   git -C {{worktree_path}} diff
   ```

## 把 findings 分类，逐条处理

对 review 报告里每个 `F<N>` finding（按 severity 排序，blocking 优先）：

- **(A) 修得动 + 在原 scope 内** —— 按 reviewer 的 "What would change your verdict" 改文件。
- **(B) 修得动 + 需要 SCOPE_EXTEND** —— 先打印 `SCOPE_EXTEND: <file> <reason>`，reason 必须映射回 task 描述或 reviewer 的具体引用，不能是"顺手清理"。
- **(C) Reviewer 误读** —— 不改代码；在 fix summary "Rejected as false positive" 节给出**反驳证据**（reviewer 引用的 file:line 在 diff 中不存在 / reviewer 引用的规则其实允许 / reviewer 引用的 task 描述与原文不符）。**禁止**在代码里加文字反驳 reviewer——反驳走 summary。
- **(D) Reviewer 之间矛盾** —— 不动；在 summary 标 conflict，末尾用 `blocked` 状态退出并打印 `FIX_BLOCKED_REASON:` 行。
- **(E) 超出 fix codex 权限**（要求删除整个 feature / 拆 PR / 改 task 边界） —— 不动；summary 标 human-decision，末尾用 `blocked` 退出。

## 硬约束

1. 只解 reviewer 的 finding。即使你看到别处有问题，那是下一个 task 的事。
2. **不动 git history**：禁止 amend / rebase / squash。fix 走 worktree 新工作区（controller 后续 commit）。
3. **保留 implement 阶段的注释块**；如果修复让原注释不准了，更新它，不要删。修复点本身额外加：

   ```
   <项目惯用注释语法> Fix (review round {{review_round}}, F<N>):
   <项目惯用注释语法>   <reviewer 指出的问题，一行>
   <项目惯用注释语法>   <你这次怎么改的，一行>
   ```

4. **跑测试**：

   ```bash
   {{test_commands}}
   ```

   每个改动涉及的模块都跑。失败修复，最多 5 次。

5. **跑 build + guard**：

   ```bash
   {{build_commands}}
   {{guard_commands}}
   ```

   失败修复。
6. **不安装新依赖**。
7. **不动外部仓库 / 父目录**。写权限只在 `{{worktree_path}}` + `{{fix_summary_path}}`。
8. **不要 commit / push / checkout / PR**。

## 流程

1. 读 review 报告、读 worktree diff、读 task 描述、读历史轮（如有）。
2. 给每个 finding 分类（A/B/C/D/E）。
3. 打印 `PLAN:` 多行，每行 `F<N>: <分类> <一句话动作>`。
4. 应用 (A) 和 (B) 的修复。每个 finding 修完立刻验证（编译 + 对应测试）。
5. 跑 build / test / guard（硬约束 4-5）。
6. `git -C {{worktree_path}} add -A && git -C {{worktree_path}} status --short`。**不要 commit**。
7. 写 fix summary 到 **绝对路径** `{{fix_summary_path}}`：

   ```markdown
   ---
   schema: vmap-codex-fix-summary-v1
   task_id: {{task_id}}
   review_round: {{review_round}}
   applied_count: N
   rejected_count: M
   blocked_count: K
   fixed_at: <ISO8601 UTC>
   ---

   ## Applied
   - F1 (A) path/file:LineRange — <做了什么修复> (addresses reviewer "What would change your verdict")
   - F2 (B) path/other — SCOPE_EXTEND reason: <…>; <做了什么>

   ## Rejected as false positive
   - F3 — reviewer 引用了 `xxx:42`，但当前 diff 中本 task 没改该文件（证据：`git diff --stat | grep xxx` 返回空）

   ## Blocked (conflict / human-decision)
   - F4 — <reviewer 的要求> vs <本轮另一 finding 或架构规则 X>，无法同时满足

   ## Build / test / guard results
   - build: pass
   - tests: <命令> → N passed, 0 failed
   - guards: pass

   ## Self-assessment: will the next review pass?
   <一段：你认为下一轮 reviewer 会不会给 pass；如果觉得不会，列哪些 finding 你处理得不彻底但又无法做得更好。这段不是装腔，是给 controller / 人 的决策输入>
   ```

8. **最末一行**打印（精确格式）：

   ```
   VMAP_CODEX_FIX_DONE:{{task_id}}:round-{{review_round}}:<status>
   ```

   `<status>` ∈ {`ok`, `blocked`}：
   - `ok`：所有 (A) 和需要的 (B) 完成，build/test/guard 全过。
   - `blocked`：存在 (D) conflict 或 (E) human-decision 的 finding 未被抵消。

   如果 status == blocked，**额外**打印一行：

   ```
   FIX_BLOCKED_REASON:<conflict|human-decision>:<short reason>
   ```

## 红线

- 禁止改与 finding 无关的代码（哪怕你觉得别处更糟）。
- 禁止把上一轮已经驳回的修复重新交（controller 会发现并把整轮判为 stuck）。
- 禁止 disable / skip 测试。
- 禁止安装新依赖。
- 禁止 `git commit` / `git push` / `git checkout` / `git rebase` / `git amend` / 任何 PR 操作。
- 禁止在代码里加文字反驳 reviewer——反驳走 summary。
- 禁止跨 worktree 读写。

开始执行。
