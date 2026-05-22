# Implement from DAG

适用场景：项目已经有 `.vmap/`，用户让你按现有图推进某个 goal / task，而不是重新整理 DAG。

如果用户明确要求“调用 Codex CLI 实现”或“无人值守跑实现循环”，不要用这份普通实现 playbook，改读 `skills/playbooks/codex-goal-implement-loop.md`。

核心原则：**先看图，再写代码**。DAG 里的 `docs` / `tests` / `gh_query` 是 reading list 和验收线索，不是装饰字段。

## 1. 找当前要做的 task

如果用户指定了 goal：

```bash
vmap list tasks --goal <goal-id> --status todo
vmap deps <goal-id>
```

如果用户只说“继续推进”：

```bash
vmap list goals --focus
vmap list tasks --status todo
```

优先选：

- deps 都已完成的 task
- `regression_testable: true` 且 tests/docs 已记录清楚的 task
- 用户明确点名的 task

不要凭印象绕过 DAG 自己挑活。

## 2. 读规格和基线

```bash
vmap show <task-id>
```

把输出里的这些东西读全：

- `docs`: PRD、README、ADR、issue URL、设计文档
- `tests`: 现有回归测试或期望新增的测试位置
- `deps`: 上游 task / goal 的约束
- `notes`: 实现细节或历史坑

然后跑基线测试。优先跑 task 记录的 tests；没有记录时，跑最近的包级测试。

## 3. 标记进行中

```bash
vmap update <task-id> --status in-progress
```

如果这一步失败，先修 DAG 状态问题，不要继续写代码。

## 4. 实现

按 task 范围做最小实现：

- 只改这个 task 需要的文件
- 先补或更新回归测试
- 不顺手重构无关模块
- 不新增 goal / 拆 task / 改 deps；这些属于维护模式

如果实现中发现 DAG 漂了（docs 漏、task 拆错、deps 反了），停下来切回维护模式，先把图修对。

## 5. 验证和回写

跑完测试后，把结果写回 DAG：

```bash
vmap update <task-id> --status done \
  --add-test <test-path> \
  --add-doc <doc-or-issue-url>
```

如果只完成了一部分：

```bash
vmap update <task-id> --status blocked --notes "卡点：..."
```

最后看 goal 进度：

```bash
vmap status --json
vmap show <goal-id>
```

## 6. 什么时候切回维护模式

遇到这些情况不要硬做：

- task 太大，已经不是一个提交能讲清楚
- task 缺 docs/tests，无法判断验收标准
- deps 显然不对
- 实现需要新增用户可感知能力，但 DAG 没有对应 goal

这时先维护 DAG，再回到实现模式。
