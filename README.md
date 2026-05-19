# vibe-map

> DAG-based progress visualization for vibe coding — Lean 4 region map style.

vibe coding 时代，AI 是主驱动写代码，人在旁边看。但"AI 写到哪一步了 / 还差多远 / 哪些路径被堵着"这件事，在传统 todo list / 工单系统里很难直观看出来。

**vibe-map** 把进度建模成一张 DAG：**goal** 是用户可见的能力（"用户能登录"），**task** 是实现路径（"写 auth middleware"），依赖关系是图的边。AI 在编码过程中**直接修改这张图**（一行 CLI），用户在浏览器里实时看到 region map 风格的可视化——已完成的实色，进行中的发亮，未来的淡入背景。

> 术语选择：用 `goal` / `task` 而不是 `milestone` / `issue`，是为了和 GitHub 自己的 milestone/issue 概念区分开——避免 AI 把"vmap 的 task"和"github issue"混用。Lean 4 证明体系里的"goal" 也是同一语义。

## 这个工具是给 AI 用的

不是 PM 工具。所有命令都有 `--json` 输出 + 稳定退出码，便于 agent 在 loop 里调用：

| 退出码 | 含义 |
|---|---|
| 0 | 成功 |
| 1 | 业务校验失败（依赖循环、id 已存在、未知节点等） |
| 2 | CLI 参数错误 |
| 3 | `audit` 发现违例（用于 AI fix-and-retry loop） |

## 三种模式

vibe-map 不假设 AI 从空白起步。三个命令覆盖三种切入方式：

### 1. Live tracking — 一边写代码一边记图
```bash
vmap init --name "我的项目"
vmap add goal --id g1 --title "用户能登录"
vmap add task --id t1 --goal g1 --title "写 auth middleware" --regression-testable
vmap update t1 --status done --tests "src/auth/middleware_test.mbt"
```

### 2. Backfill — 已有的 codebase 反推节点
扫源码树，自动探测语言（moonbit / typescript / dotnet 内置模板，可加 `--template-file path.json` 自定义），每个包变成 goal，每个源文件变成 done 的 task：
```bash
vmap backfill --src .
# typescript 项目：72 goals / 209 tasks (chengsheng)
# dotnet 项目：    19 goals (namespace 分组) / 1018 tasks (aevatar)
# moonbit 项目：   3 goals / 8 tasks (vmap 自己)
```
每个内置模板就是一份 JSON，描述"什么算包 / 什么算源文件 / 测试和文档怎么绑"。**加一个语言 = 写一个 JSON**，不需要改 vmap 的代码。

### 3. Plan — 已有文档反推 todo 节点
扫 markdown 文件，把里面的待办项抽成 todo 节点。`--format` 选择解析器：
- `checklist`（默认）：`- [ ]` 未勾选项；每个 `.md` 文件 = goal，每条 = task
- `tlist`：识别 `## T<N> — <title>` + `**Status:** ✅ resolved | open | partially resolved | blocked` 这种结构化 TODO 段（比如 chengsheng 的 `TODOS.md`），status 自动映射到 vmap 四态

```bash
vmap plan --docs ROADMAP.md docs/
vmap plan --docs TODOS.md --format tlist
```

代码块（` ``` ` / `~~~`）内的 checklist 自动跳过，`[x]` 已勾选的自动跳过，重跑幂等。

## 质量守门：`vmap audit`

vibe coding 最容易出的问题是"看起来都做完了，但都没测试 / 没文档"。`audit` 检查两条规则：

- `regression_testable: true` 但 `tests: []` → `missing_tests`
- `status != todo` 但 `docs: []` → `missing_docs`（todo 节点不卡，没写完当然没文档）

```bash
vmap audit               # 文本
vmap audit --json        # JSON，给 AI parse
echo $?                  # 有违例 = 3
```

AI 工作流大概是：

```
vmap audit --json > /tmp/v
# parse violations, 给每个 missing_tests 写测试 / 给每个 missing_docs 写文档
# vmap update <id> --tests …  或  vmap update <id> --docs …
# 再 audit，直到 exit 0
```

## 可视化：Sisyphus 风格拓扑工作台

```bash
vmap render --out dag.html
open dag.html
```

- **暗色 canvas 拓扑图**：发光节点、点阵背景、可拖拽/缩放/适配视图
- **形状 = kind**：六边形 = goal，圆形 = task
- **颜色 = status**：done 绿 / in-progress 蓝 / blocked 红 / todo 灰
- **左侧进度面板**：按 goal 展示完成度
- **右侧详情面板**：显示节点依赖、被依赖、tests / docs / notes
- 点节点 → 高亮整条传递依赖链
- 单个自包含 HTML 文件，无前端框架和 CDN 运行依赖

`examples/dag.html` 是这个项目自己 dogfood 出来的渲染结果。

## CLI 一览

```
vmap init                       Create a new vibe-map.json
vmap add goal …                 Add a goal
vmap add task …                 Add a task
vmap update <id> …              Update fields (只改你显式传的那些)
vmap rm <id>                    Remove a goal or task
vmap import --in <path>         Bulk-load a hand-crafted vibe-map.json
vmap render --out X.html        Render a self-contained HTML page
vmap status [--json]            Text or JSON summary (含 goal 进度)
vmap audit [--json]             Quality gate (tests + docs)
vmap backfill --src DIR         Auto-detect template, synthesize from source
vmap plan --docs F,…            Synthesize from markdown (checklist or tlist)
```

每个命令 `--help` 看完整 flag。模板系统：`--template moonbit|typescript|dotnet` 或 `--template-file path.json` 自定义；不传 = 从项目结构自动探测。

## 数据模型

落地在一个 `vibe-map.json`，AI 可以直接读：

```jsonc
{
  "project": { "name": "…", "description": "…" },
  "goals": [{
    "id": "g1",
    "title": "用户能登录",
    "description": "",
    "deps": [],                     // 跨 goal 依赖
    "regression_testable": false,
    "tests": [],                    // 测试文件 / glob
    "docs": []                      // 文档路径
  }],
  "tasks": [{
    "id": "t1",
    "goal": "g1",
    "title": "写 auth middleware",
    "status": "todo | in-progress | blocked | done",
    "deps": [],                     // 同层 task 依赖
    "notes": "",
    "regression_testable": false,
    "tests": [],
    "docs": []
  }]
}
```

依赖在添加时做循环检测；删 goal 会连带删它的 task 并清理其它节点中指向它的 deps。

## 构建

[MoonBit](https://www.moonbitlang.com/) 写的（学习项目 + vibe coding 友好的工具栈）。

```bash
moon install                # 拉 moonbitlang/x 依赖
moon build --target native  # 出 native 二进制
# → _build/native/debug/build/cmd/vmap/vmap.exe
moon test                   # 23 tests
moon fmt && moon check
```

## 路线图

短期：
- [ ] `vmap serve`：watch JSON + 浏览器实时刷新（需要 MoonBit 端最小 HTTP server）
- [ ] MCP wrapper：让 Claude Code / Codex / Cursor 直接调 vmap，不用走 Bash
- [ ] symbol-level backfill：用 `moon ide outline` 拿公开符号粒度，而不是按文件

中期：
- [ ] cross-language adapter（Rust / Go / Python 的包/文件约定）
- [ ] LLM-assisted plan：从自由文本 README/设计文档抽 todo，不只 `- [ ]` checklist
- [ ] 节点详情面板（点击后侧栏显示 tests / docs / notes）
- [ ] "north star" 节点形状（star）+ 一键聚焦最关键路径

## 许可证

待定。在确定之前，默认 all rights reserved；想用请到 GitHub 提 issue 沟通。
