# Playbook — 用户问"现在做到哪了"

> 给 coding agent 用的"快速报告"模板。

## 用户的常见问法

- "现在做到哪了？"
- "0.4 还差啥？"
- "今天进度怎么样？"
- "卡哪了？"

## 一行响应

```bash
vmap status                # 完整文本，含 goal 进度
```

用户大概率会自己 `open .vmap/vibe-map.html` 看图，但你给一个文字摘要也好。

## 按 release 看

```bash
vmap status --release 0.4.0
```

输出每个 goal 的 task 完成度。

```bash
vmap release list                 # 全部 release + 成员数
vmap release list --json          # 给你 parse 用
```

## 看焦点

```bash
vmap list goals --focus
```

这是"现在正在做的"。

## 看卡点

```bash
# 哪些 goal 还在 scoped / obligation / seed（没到 public）
vmap list goals --release 0.4.0 --closure scoped
vmap list goals --release 0.4.0 --closure obligation

# 哪些 task 还在 blocked
vmap list tasks --status blocked

# 哪些 task 还在 in-progress
vmap list tasks --status in-progress
```

## 看具体一个 goal 的全貌

```bash
vmap show goal-release-modeling
```

输出含：
- closure / focus / archived / regression_testable
- milestone / owner / issue_count
- deps + upstream/downstream（传递闭包）
- 所有 task 的 status + title

JSON 版：
```bash
vmap show goal-release-modeling --json
```

## 看依赖链

```bash
vmap deps goal-llm-plan
# 输出 goal-llm-plan 的上游（它要依赖的）和下游（依赖它的）
```

如果你卡在某个 goal 没法推进，看它的 upstream，可能有前置 goal 还没做完。

## 一个完整报告示例

用户说"今天进度怎么样"：

```bash
$ vmap list goals --focus
• [goal-audit] Audit — 质量守门  closure=scoped milestone=0.4.0 owner=eanzhao  (3/6 · 50%)
• [goal-viz] Visualization — 暗色 canvas region map  closure=scoped milestone=0.4.0 owner=eanzhao  (5/7 · 71%)
• [goal-release-modeling] Release lanes  closure=scoped milestone=0.4.0 owner=eanzhao  (7/9 · 77%)
• [goal-cli-dag-mgmt] CLI for AI-driven DAG management  closure=public milestone=0.4.0 owner=eanzhao  (12/12 · 100%)

$ vmap list tasks --status in-progress
(0 tasks matched)

$ vmap list tasks --status blocked
(0 tasks matched)
```

你回用户：

> 0.4.0 正在收尾。`goal-cli-dag-mgmt`（AI 管 DAG 的 CLI 表面）刚做完 100%（12/12），closure 推到 public 了。还剩三个 in-flight goal：`goal-release-modeling`（77%，缺 release status / close 命令）、`goal-viz`（71%，缺 release filter UI）、`goal-audit`（50%，缺 release_blocked / release_unknown 规则 + audit --release 过滤）。没有 blocked / in-progress 的 task——下一步是从这三个 goal 里挑一个继续推。可以打开 `.vmap/vibe-map.html` 看图。

## 反例

❌ **"现在做了 47 个 task"** —— task 计数对人没用，给百分比 + 焦点更有信息量。

❌ **"在写 src/core/ops.mbt"** —— 文件名是实现细节，用 goal 标题更接近用户视角。

❌ **空报告**：跑了 `vmap status` 但没读输出就回 "进度还行" —— 让你回的不是公关稿。

## 数据快照（给用户存档）

如果用户想留一份"今天的进度报告"：

```bash
vmap status --json > snapshots/$(date +%Y%m%d).json
```

或者复制当前的 viz：

```bash
cp .vmap/vibe-map.html snapshots/$(date +%Y%m%d).html
```

> 注意：vmap 没有内建 snapshot 命令，这是约定俗成的做法。
