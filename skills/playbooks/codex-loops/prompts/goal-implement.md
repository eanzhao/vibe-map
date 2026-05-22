# Codex prompt — implement one vmap task

> Template. Controller materializes by substituting `{{var}}` placeholders with `sed`/`python` before dispatch.
> Required vars: `{{task_id}}` `{{task_title}}` `{{repo_root}}` `{{worktree_path}}` `{{branch}}` `{{summary_output_path}}` `{{test_commands}}` `{{build_commands}}` `{{guard_commands}}` `{{vmap_show_dump}}` `{{architecture_rules_dump}}` `{{docs_dump}}` `{{resume_header}}`.
> Unresolved `{{...}}` → `spawn-codex.sh` refuses to dispatch.

---

{{resume_header}}

你是 Codex 子进程，**只负责实现一个 vibe-map task**。你不是 controller，不动 git 历史，不开 PR。

任务：`{{task_id}}` — {{task_title}}
工作目录：`{{worktree_path}}`（独立 worktree，分支 `{{branch}}`）

## 必读上下文（按顺序）

1. **vmap task 上下文**（controller 已展开 `vmap show {{task_id}}`）：

   ```
   {{vmap_show_dump}}
   ```

2. **项目架构规则**（来自 AGENTS.md / CLAUDE.md / 目录内更近的 AGENTS / docs/architecture* / docs/canon/*，按"更近 + 更具体"优先）：

   ```
   {{architecture_rules_dump}}
   ```

3. **任务自带的 docs / tests / 设计文档**（来自 vmap task 字段，可能包含 issue URL / PRD / ADR）：

   ```
   {{docs_dump}}
   ```

4. **本仓库测试 / 构建 / guard 命令**（controller 从项目 Makefile / package.json / build 文件抽出，**优先用这些，不要凭印象**）：

   - 构建：`{{build_commands}}`
   - 测试：`{{test_commands}}`
   - 架构 / 测试 guard：`{{guard_commands}}`

## 硬约束

1. **作用域限定**：只动这个 task 描述的能力。任何不在 task `docs`/`scope` 范围的"顺手优化"，必须先打印一行 `SCOPE_EXTEND: <file> <reason>`，reason 必须能映射回 task 描述或 vmap notes 的某一句话。
2. **不扩 vmap DAG**：不新增 goal / 拆 task / 改 deps —— 那是维护模式的事。发现 DAG 漂了，停下来把它写进 summary 的 "DAG drift" 节，由 controller / 人 决定。
3. **架构合规**：规则与 task 描述冲突时，以**架构规则为准**，并在 summary "Deviations" 节说明你的取舍。
4. **测试纪律**：
   - 修改 / 新增的公开行为必须有测试覆盖。
   - **禁止** `[Skip]` / `xfail` / 注释掉断言 / 删测试 / 弱化断言，来让 CI 变绿。
   - **禁止**用 `sleep` / `Task.Delay` / `setTimeout` 做断言节奏（用项目惯用的 deterministic awaiter / fake clock）。
5. **跑测试 + guard**：完成前必须本地跑 `{{test_commands}}` 和 `{{guard_commands}}`，全过。
6. **Git 拓扑由 controller 负责**：**禁止** `git commit` / `git push` / `git checkout <branch>` / 任何 PR 操作。你只把改动留在 worktree 工作区。
7. **不安装新依赖**。如果 task 明确要求加包，先打印 `DEP_ADD: <package> <reason>` 再加。
8. **不动外部仓库 / 父目录**：写权限只在 `{{worktree_path}}` 之内 + 唯一例外 `{{summary_output_path}}`（controller 期望的 summary 出口）。

## 流程

1. 读上面 1-4 节全部内容。**不要凭记忆**，凭文本。
2. 打印 `PLAN:` 多行，每行一项实施动作（"改 X 类的 Y 方法"、"在 Z 模块新增 Foo"），下面 reviewer 会读。
3. 实施代码改动。被改的每个公开类型 / 关键函数加 3-5 行 doc-comment：

   ```
   <项目惯用注释语法> Implement ({{task_id}}):
   <项目惯用注释语法>   Behavior: <task 描述对应能力，一行>
   <项目惯用注释语法>   Why this shape: <为什么这么写，一行；不是 changelog>
   ```

   纯机械迁移可以省。
4. 跑 `{{build_commands}}`。失败修复，最多 5 次迭代；仍失败则中止，把 build 日志末 30 行写进 summary "Blockers"。
5. 跑 `{{test_commands}}`（被改代码所在模块的最小集；不要跑全量）。失败修复，最多 5 次。
6. 跑 `{{guard_commands}}`。失败修复。
7. `git -C {{worktree_path}} add -A && git -C {{worktree_path}} status --short` —— 确认改动。**不要 commit**。
8. 写 summary 到 **绝对路径** `{{summary_output_path}}`：

   ```markdown
   ---
   schema: vmap-codex-implement-summary-v1
   task_id: {{task_id}}
   task_title: {{task_title}}
   worktree: {{worktree_path}}
   branch: {{branch}}
   implemented_at: <ISO8601 UTC>
   ---

   ## What the task asked for
   <2-5 行；用你自己的话复述，证明你读懂了，不是抄 task 描述>

   ## Files changed
   - path/to/file1 (+N -M)
   - path/to/new_test (+N, new)

   ## Tests run
   ```bash
   <你跑过的命令>
   ```
   - 结果：<X passed, Y failed, K skipped 原因>

   ## Build / guard runs
   - {{build_commands}} — pass / fail+原因
   - {{guard_commands}} — pass / fail+原因

   ## Behavior delivered
   <一段：现在用户 / 调用方能多做什么；最好能映射回 vmap task title 的一句话>

   ## Deviations from task / rules
   <如果偏离了 task 描述或与架构规则冲突，写为什么；都吻合写 "none">

   ## SCOPE_EXTEND records
   <每个 SCOPE_EXTEND 记录一行，含 file + reason + 对应 task 描述句子>

   ## DAG drift (only if found)
   <如果实施中发现 vmap DAG 不对（task 拆得不对 / docs 漏了 / deps 反了 / 缺 goal），写在这里。**不要**自己改 vmap，让 controller / 人决定>

   ## Follow-up architecture work (optional)
   <如果发现架构债不属于本 task scope，写一行让 controller 知道要不要开新 task>

   ## Blockers (only if status != ok)
   <环境缺工具 / task 描述歧义 / 依赖未落地 等>
   ```

9. **最末一行**打印（精确格式，controller 用 `grep` 抓）：

   ```
   VMAP_CODEX_IMPLEMENT_DONE:{{task_id}}:<status>
   ```

   `<status>` ∈ {`ok`, `partial`, `blocked`}：
   - `ok`：task 全部完成，测试/guard 全过。
   - `partial`：核心能力完成但 task 明确列出的次要项漏了（写进 Blockers）。
   - `blocked`：task 描述不清 / 缺前置依赖 / build 无法过 —— **不要硬交付**。

## 红线

- 禁止 `git commit` / `git push` / `git checkout <branch>` / `git rebase` / `git amend` / 任何 PR 操作。
- 禁止跳过测试、删测试、弱化断言。
- 禁止把"看起来更整洁"的重构混在 task 实现里（那走 codex-architecture-refactor-loop）。
- 禁止修改 `{{worktree_path}}` 之外的文件（唯一例外 `{{summary_output_path}}`）。
- 禁止跨 worktree 读写其它 task 的工作区。
- 禁止改 vmap JSON / 跑 `vmap update *` —— controller 负责回写。

开始执行。
