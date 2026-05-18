# vibe-map

> DAG-based progress visualization for vibe coding — Lean 4 region map style.

vibe coding 时代，AI 是主驱动写代码，人在旁边看。但"AI 写到哪一步了 / 还差多远 / 哪些路径被堵着"这件事，在传统 todo list / issue tracker 里很难直观看出来。

**vibe-map** 把进度建模成一张 DAG：milestone 是用户可见的能力（"用户能登录"），issue 是实现路径（"写 auth middleware"），依赖关系是图的边。AI 在编码过程中**直接修改这张图**（一行 CLI），用户在浏览器里实时看到 region map 风格的可视化——已完成的实色，进行中的发亮，未来的淡入背景。

## 这个工具是给 AI 用的

不是 PM 的 issue tracker。所有命令都有 `--json` 输出 + 稳定退出码，便于 agent 在 loop 里调用：

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
vmap add milestone --id m1 --title "用户能登录"
vmap add issue --id i1 --milestone m1 --title "写 auth middleware" --regression-testable
vmap update i1 --status done --tests "src/auth/middleware_test.mbt"
```

### 2. Backfill — 已有的 codebase 反推节点
扫源码树，每个包变成 milestone，每个源文件变成 done 的 issue，自动绑定同名 `_test.mbt` 和 `README*.md`：
```bash
vmap backfill --src src
# +3 milestones, +8 issues, 自动绑定 5 个 *_test.mbt
```
v1 只支持 MoonBit（用 `moon.pkg` 划包）；其它语言可以按目录粗粒度，已在路线图。

### 3. Plan — 已有文档反推 todo 节点
扫 markdown 文件里 `- [ ]` 未勾选项；每个 `.md` 是一个 milestone，每个 checklist 项是一个 todo issue：
```bash
vmap plan --docs ROADMAP.md docs/
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

## 可视化：Lean 4 region map 样式

```bash
vmap render --out dag.html
open dag.html
```

- **扁平 DAG**（不是 Kanban 盒套盒）
- **形状 = kind**：六边形 = milestone，圆形 = issue
- **颜色 = status**：done 绿 / in-progress 蓝 / blocked 红 / todo 灰
- **透明度 = 焦点**：todo 节点淡化，让正在做的事自然显眼
- **粗红箭头 = 依赖**；从属关系（milestone→issue）只用极淡虚线做布局提示
- 点节点 → 高亮整条传递依赖链
- 单个自包含 HTML 文件，Cytoscape.js 走 CDN（要联网）

`examples/dag.html` 是这个项目自己 dogfood 出来的渲染结果。

## CLI 一览

```
vmap init                       Create a new vibe-map.json
vmap add milestone …            Add a milestone
vmap add issue …                Add an issue
vmap update <id> …              Update fields (只改你显式传的那些)
vmap rm <id>                    Remove a milestone or issue
vmap render --out X.html        Render a self-contained HTML page
vmap status [--json]            Text or JSON summary (含 milestone 进度)
vmap audit [--json]             Quality gate (tests + docs)
vmap backfill --src DIR         Synthesize from existing MoonBit source
vmap plan --docs FILE|DIR,…     Synthesize todo nodes from markdown
```

每个命令 `--help` 看完整 flag。

## 数据模型

落地在一个 `vibe-map.json`，AI 可以直接读：

```jsonc
{
  "project": { "name": "…", "description": "…" },
  "milestones": [{
    "id": "m1",
    "title": "用户能登录",
    "description": "",
    "deps": [],                     // 跨 milestone 依赖
    "regression_testable": false,
    "tests": [],                    // 测试文件 / glob
    "docs": []                      // 文档路径
  }],
  "issues": [{
    "id": "i1",
    "milestone": "m1",
    "title": "写 auth middleware",
    "status": "todo | in-progress | blocked | done",
    "deps": [],                     // 同层 issue 依赖
    "notes": "",
    "regression_testable": false,
    "tests": [],
    "docs": []
  }]
}
```

依赖在添加时做循环检测；删 milestone 会连带删它的 issue 并清理其它节点中指向它的 deps。

## 构建

[MoonBit](https://www.moonbitlang.com/) 写的（学习项目 + vibe coding 友好的工具栈）。

```bash
moon install                # 拉 moonbitlang/x 依赖
moon build --target native  # 出 native 二进制
# → _build/native/debug/build/cmd/vmap/vmap.exe
moon test                   # 18 tests
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

待定。在确定之前，默认 all rights reserved；想用请提 issue。
