[English](README.md) | **简体中文**

# vibe-map

> Coding agent 用一行 CLI 修一张 goal DAG，人在 `.vmap/vibe-map.html` 看 Lean 4 region map 风格的实时进展。

![vibe-map dashboard](https://raw.githubusercontent.com/eanzhao/vibe-map/master/examples/dashboard.png)

> 上图是 vibe-map 自己 dogfood 出来的 self-map。`examples/dag.html` 是 live 版本，本地 `open` 可看。

## 长期目标

Vibe coding 时代，AI 是主驱动写代码，人在旁边看、把方向。两个状态用户**时时刻刻**都需要知道：*现在做到哪了？* 和 *下一步如果交付出去，会不会破坏前面已经做完的？* GitHub issue 和扁平 todo list 都答不了这两个问题。

`vibe-map` 的产品形态是 **一个 `vmap` CLI + 一组 skills**。CLI 本身很轻，用户真正消费的产物只有一个文件 —— `.vmap/vibe-map.html` —— 实时的 goal DAG 执行图：哪些做完了、下一步做哪个、谁被堵着、再发版会不会踩到雷。

下面是长期蓝图（大部分还没完全实现）：

1. **给 coding agent 用，不是给 PM 用。** 这个仓库里所有东西都是为 coding agent 设计的：没有 PM dashboard、没有 IDE 插件、没有后台 daemon —— 就一个 agent 可以直接 `exec` 的 CLI，加上它读得懂的 skills。
2. **全新项目 → DAG。** 对于刚起步的项目，coding agent 跟用户头脑风暴（配合 [gstack](https://github.com/gstack/gstack) 这类 skills 整出来的文档），然后通过 vibe-map 把文档拆成 goal 和 task，产出可执行的 `.vmap/vibe-map.html`。
3. **已有代码的项目 → DAG。** 对于已经有一些代码量的项目，coding agent 通过 vibe-map 反向归纳出已经实现的 goal，从那里继续往前推进。
4. **每个 goal 都有回归测试集。** 每个 goal 都挂着证明它能工作的测试。用户可以**随时**跑完整回归测试集。当一个新 goal 把旧 goal 弄坏了，vibe-map 会**精确指出**是哪个 goal 回归了 —— 用户（或者 agent 帮用户）按 vibe-map 的提示去 fix，或者如果是 goal 本身定义变了，就调整 goal。
5. **端到端闭环。** 只要用户的需求被打磨得足够清晰 —— 不管是通过 gstack 这类 skill 走过一遍，还是自己记录的想法已经比较成规模 —— 就可以把它丢给 coding agent。vibe-map 把它拆成 DAG，agent 一个 goal 一个 goal 地实现，直到原始需求被完整交付，闭环才结束。
6. **开源开放。** 欢迎 issue、fork、PR。

每一条今天落地到什么程度，看下方的 [状态](#状态)。

## 安装

```bash
# macOS arm64 / Linux x86_64 / Linux arm64 预编译
curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh | bash
```

会把 `vmap` 放到 `~/.local/bin/`，skills 放到 `~/.vmap/skills/`。如果 `~/.local/bin` 不在 `$PATH`，脚本会提示你加。

> Intel Mac (`darwin-x86_64`) 当前不在预编译矩阵里（GitHub Actions `macos-13` runner 排队太慢）。Intel mac 用户先从源码装。

**从源码装**（已有 MoonBit 工具链 + 想本地改）：

```bash
git clone https://github.com/eanzhao/vibe-map && cd vibe-map
moon install && moon build --target native --release
./install.sh --local "$PWD"
```

详细分发设计见 [`docs/distribution.md`](docs/distribution.md)。

## 让你的 coding agent 用 vmap

复制下面这一整段，发给 Claude Code / Codex / Cursor / 任何 coding agent，它就会自动装 vmap、读懂工作模式、开始在你项目里维护 DAG：

````text
帮我用 vibe-map（vmap）维护这个项目的进度。

如果还没装 vmap：
  curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh | bash
  # 如果 ~/.local/bin 不在 PATH，按脚本提示加到 ~/.zshrc 然后 source 一下

读懂规则（必读）：
  cat ~/.vmap/skills/SKILL.md
  ls ~/.vmap/skills/playbooks/

在项目根初始化（如果 .vmap/ 不存在）：
  vmap init --name "我的项目"
  # 把 .vmap/ 加到 .gitignore

之后所有进展都用 vmap CLI 记下来：
  - 我说一个需求 → 你按 PRD 视角抽 goal（语义层，不是按代码包！），vmap add goal
  - 拆任务 vmap add task --deps ...
  - 写完一个 task vmap update <id> --status done
  - goal 推到一个阶段 vmap update <goal> --closure scoped/public/...
  - 关键节点 vmap audit，按违例修 tests/docs

约束：
  - goal 是 PRD 上的"用户能感知的能力"，不是代码 package
  - closure 单调推进（seed → obligation → scoped → public → bridged → mature），不能回退
  - 不要手改 .vmap/vibe-map.json，所有改动走 vmap CLI
  - 退出码 1=业务错误 / 2=参数错 / 3=audit 违例

具体怎么做查 ~/.vmap/skills/playbooks/：
  new-feature.md / audit-fix-loop.md / release-shipping.md / daily-progress.md
  codex-goal-implement-loop.md / codex-architecture-refactor-loop.md
命令速查 ~/.vmap/skills/cheatsheet.md。

每次 vmap mutating 命令会自动刷新 .vmap/vibe-map.html，我随时打开看。开始吧。
````

更详细的版本 + 调试技巧见 [`skills/vibe-map-bootstrap.md`](skills/vibe-map-bootstrap.md)。如果项目里已经有 `.claude/skills/vibe-map-bootstrap/SKILL.md`（vibe-map 这个 repo 自带一份），Claude Code 打开就会自动加载，连 prompt 都不用复制。

## 委托 Codex 执行的循环

vibe-map 也可以指导一个 controller agent，把真正的代码修改派给 Codex CLI：

- [`codex-goal-implement-loop.md`](skills/playbooks/codex-goal-implement-loop.md) 把 DAG 当任务队列：controller 读 vmap task，整理 docs/tests/架构上下文，在 worktree 里跑 `codex exec`，review diff，再回写 vmap。
- [`codex-architecture-refactor-loop.md`](skills/playbooks/codex-architecture-refactor-loop.md) 把 `AGENTS.md`、`CLAUDE.md` 和架构文档抽成明确规则，让 Codex 审计违例，把每个重构 cluster 写回 vmap task，然后循环 implement / review / verify。

核心分工：controller 管 vmap 状态和 git/PR 拓扑；Codex 子进程负责源码修改。人看的状态面仍然是 `.vmap/vibe-map.html`。

## vibe-map 建模的是什么

进度被建模成一张 DAG：

- **goal** —— PRD 上的一条**语义目标**（"用户能登录"、"支持 release 维度"），不是代码 package
- **task** —— 实现这个 goal 需要做的具体动作；一个 goal 的 task 经常**跨多个源文件 / package**
- **release** —— 版本边界（"0.5.2"），把 goal 归到版本，告诉 agent "这一版要交付什么"
- **依赖**是图的边（语义层），不是源码 import 层

Coding agent 用一行 CLI 修这张图，人在浏览器看 region map 风格的可视化 —— 已完成的实色、进行中的发亮、未来的淡入背景。

> 术语：用 `goal` / `task` 而不是 `milestone` / `issue`，避免和 GitHub 自己的 milestone/issue 概念混淆。"region map" 视觉风格借鉴 Lean 4 证明体系 —— `goal` / `focus` / `closure` 都是同一类语义。

## 给 coding agent 用，不是 PM 工具

所有命令都有 `--json` 输出 + 稳定退出码：

| 退出码 | 含义 |
|---|---|
| 0 | 成功 |
| 1 | 业务校验失败（依赖循环、id 已存在、未知节点、release 校验失败等） |
| 2 | CLI 参数错误 |
| 3 | `audit` 发现违例（驱动 fix-and-retry loop） |

所有状态落在单一 `vibe-map.json`，agent 可以直接读。无 MCP、无 daemon、无 IDE 插件 —— **CLI-only**，让 agent 直接 `exec`。

## 数据接入

三种切入方式，**重要性递减**：

### 1. Live tracking — 主线（PRD-driven）

Agent 边读 PRD / 设计文档边记图。这是 vibe-map 的核心使用方式：

```bash
vmap init --name "我的项目"
vmap add goal --id g-login --title "用户能登录"
vmap add task --id t-auth --goal g-login --title "写 auth middleware" --regression-testable
vmap update t-auth --status done --tests "src/auth/middleware_test.mbt"
```

### 2. Plan — 辅线（从 markdown 抽 todo）

扫 markdown，把待办抽成 goal/task：

```bash
vmap plan --docs ROADMAP.md docs/         # 默认抽 `- [ ]` checklist
vmap plan --docs TODOS.md --format tlist  # 抽 `## T<N> — title` + `**Status:**` 结构化 TODO 段
```

代码块 / 已勾选项自动跳过，重跑幂等。

> 当前 plan 只抽显式 checklist。从自由文本 PRD 抽**语义** goal 是 1.0.0 的事（`goal-llm-plan`）—— 也是解锁长期目标第 2 点的关键。

### 3. Backfill — 救援工具（从老 codebase 反推）

对**已有但没记录过 goal 的代码**做反向追溯。**每个 package → 一个 goal，每个源文件 → 一个 done task**：

```bash
vmap backfill --src . --template moonbit      # 内置: moonbit | typescript | dotnet
vmap backfill --src . --template-file path.json
```

> ⚠️ 这只对"事后追溯"有意义。**产品能力依赖 ≠ 代码包结构** —— backfill 出来的 goal 是 package-shaped，不是 PRD-shaped。一旦项目跑起来，主入口应该回到 live tracking。

## Release lanes — 版本边界

vibe coding 最容易跑偏的事：AI 没有版本边界感，加了 scope 停不下来。release 维度把这事建模进 DAG：

```bash
vmap release add 0.5.2 --label-en "publish to mooncakes.io" --label-zh "发布到 mooncakes.io" \
                       --target 2026-05-20 --status open
vmap release assign 0.5.2 --goals goal-publish,goal-licensing
vmap status --release 0.5.2           # 文本，按 release 过滤
vmap status --release 0.5.2 --json    # AI loop 友好
vmap release list [--json]
```

Release `status` 状态机单调：`planned → open → closed`，不允许倒退（`ReleaseStatusRegression`）。Goal 通过 `milestone` 字段指向 `release.key`，**软校验** —— 配了 `releases` 才校验，老数据 `milestone="anything"` 不会被卡。

## 质量守门 `vmap audit`

```bash
vmap audit               # 文本
vmap audit --json        # JSON
echo $?                  # 0 干净 / 3 有违例
```

当前规则：

- `regression_testable: true` 但 `tests: []` → `missing_tests`
- `status != todo` 但 `docs: []` → `missing_docs`
- goal 缺 region metadata（closure / owner / `issue_count` / `focus` / `archived` / `promoted_at` / `gh_query`）→ `missing_region_metadata`

GitHub issue 数漂移用独立脚本（依赖 `gh` CLI）：

```bash
python3 tools/audit_github.py --file vibe-map.json [--strict] [--markdown]
```

Agent audit loop 大概是：

```
vmap audit --json > /tmp/v
# parse violations → 给每个 missing_tests 写测试 / missing_docs 写文档 / 补 region metadata
# vmap update <id> --tests ... / --docs ... / --owner ...
# 再 audit，直到 exit 0
```

> 当前 `audit` 只校验"测试是否列在 goal 上"。**真正跑回归测试集、跑挂了就拦发版、并指出是哪个 goal 回归 —— 长期目标第 4 点 —— 是 `goal-regression-runner`，尚未开始。**

## 可视化

```bash
vmap render --out examples/dag.html
open examples/dag.html
```

- 暗色 canvas goal DAG，发光节点、点阵背景，可拖拽 / 缩放 / 适配视图
- **画布只展 goal**，task 收进 goal 详情面板
- **颜色 = closure tier**：seed → obligation → scoped → public → bridged → mature
- **大小 = `issue_count`**，红框 = 当前 focus，半透明 = archived
- 左侧进度面板（按 goal）+ 搜索 + product 过滤 + 状态按钮（全部 / 焦点 / 进行中 / 封档）
- 右侧节点详情：closure / formal / owner / product / milestone / promoted_at / 每个 task 的 status / tests / docs / notes
- 点节点 → 高亮整条传递依赖链
- 单文件 self-contained HTML，无 CDN / 无框架运行依赖

`examples/dag.html` 是 vibe-map 自己的 self-map。

## CLI 一览

```
vmap init                              创建 vibe-map.json
vmap add goal …                        加 goal
vmap add task …                        加 task
vmap update <id> …                     编辑任意字段（不传的不动）
vmap rm <id>                           删 goal 或 task
vmap rename <old> <new>                改 id（连带修所有 deps / task.goal 引用）
vmap show <id> [--json]                单节点完整详情（含 tasks / upstream / downstream）
vmap list goals [filters] [--json]     按属性过滤列 goal
vmap list tasks [filters] [--json]     按属性过滤列 task
vmap deps <id> [--upstream/--downstream/--json]  传递依赖图
vmap context <id>                      JSON 最小上下文：files + ancestorGoals
vmap import --in <path>                批量加载手写的 vibe-map.json（校验 + 写盘）
vmap render --out X.html               出可视化 HTML
vmap status [--json] [--release K]     文本 / JSON 摘要（可按 release 过滤）
vmap audit [--json]                    质量守门
vmap coverage [--json]                 DAG 引用了多少 docs / src / issues（防漏门槛）
vmap doctor [--json]                   健康度告警（density / lane / orphan / mismatch）
vmap backfill --src DIR                从源码反推（救援工具）
vmap plan --docs F,…                   从 markdown 反推
vmap release add <key>                 加 release lane
vmap release list [--json]             列 releases
vmap release update <key> --status/--target/--label-en/--label-zh/--notes
vmap release assign <key> --goals      批量分配 goal 到 release
vmap release unassign <key> [--goals]  从 release 清掉 goal（默认清全部）
vmap release rm <key> [--force]        删 release（有成员需 --force）
vmap version [--check]                 打印版本
vmap upgrade                           打印升级命令（管道到 bash 执行）
```

`--help` 看每条的完整 flags。

`vmap update <id>` 字段速查（通用 + 各自专属）：

- **通用**：`--title`、`--regression-testable`、`--tests a,b,c`（替换）、`--add-test`/`--remove-test`、`--docs`/`--add-doc`/`--remove-doc`、`--deps a,b,c`（替换）、`--add-dep`/`--remove-dep`
- **仅 goal**：`--description`、`--closure`、`--formal`、`--product`、`--milestone`、`--owner`、`--issue-count`、`--focus`/`--archived`、`--promoted-at key=date,…`、`--gh-query`
- **仅 task**：`--status`、`--notes`、`--goal <new-goal>`（把 task 移到另一个 goal）

`closure` 单调推进（不能回退）；`add-dep` 自动跑循环检测；`rename` 自动改所有 `deps` 引用 + `task.goal` 指针。

## 数据模型

落在 `vibe-map.json`，agent 可直接读：

```jsonc
{
  "config": { /* products / closure_tiers / formal_levels / ui */ },
  "project": { "name": "...", "description": "..." },
  "releases": [
    { "key": "0.5.2", "label": {"en":"publish to mooncakes.io","zh":"发布到 mooncakes.io"},
      "target": "2026-05-20", "status": "planned|open|closed", "closed_at": null }
  ],
  "goals": [{
    "id": "goal-login",
    "title": "用户能登录",
    "deps": ["goal-schema"],            // 跨 goal 依赖（语义层，不是源码 import）
    "closure": "scoped",                // seed → obligation → scoped → public → bridged → mature（单调）
    "formal": "checked",                // none / sop / checked / audited
    "product": "default",
    "milestone": "0.5.2",               // 指向 release.key（软校验）
    "owner": "eanzhao",
    "issue_count": 3,
    "focus": true,
    "archived": false,
    "promoted_at": { "scoped": "2026-05-19" },
    "gh_query": "is:issue label:goal-login",
    "regression_testable": true,
    "tests": [], "docs": []
  }],
  "tasks": [{
    "id": "t-auth", "goal": "goal-login",
    "title": "auth middleware",
    "status": "todo | in-progress | blocked | done",
    "deps": [],                         // 同层 task 依赖
    "notes": "",
    "regression_testable": true,
    "tests": [], "docs": []
  }]
}
```

老 JSON 缺新字段也能读（Option 字段自动 = None / 默认）。`closure` 单调推进在 `set_goal_closure` 时校验。Release 维度软校验：`releases` 非空时 `assign_release` 才校验 key 在内。

`vmap context <id>` 只从现有 schema 推导：`deps` 给出祖先图，
`docs` / `tests` 是节点归属的文件列表。命令返回确定性 JSON：

```json
{ "files": ["..."], "ancestorGoals": ["..."] }
```

## 状态

> 机器友好：`vmap release list --json`。下面是人友好版。

### 在飞 — 0.4.0（release modeling + audit + viz polish，目标 2026-06-15）

| Goal | 进展 |
|---|---|
| **goal-release-modeling** —— release lanes 数据 + CLI | Stage 1 ✓（add/list/update/assign/unassign/rm、status --release、release_progress）；Stage 2 待做（release status / close） |
| **goal-cli-dag-mgmt** —— agent 管 DAG 的 CLI 表面积 | ✓ `update --deps/--add-dep/--remove-dep/--goal/--notes/--description/--add-test/--remove-test/--add-doc/--remove-doc`、`show <id>`、`list goals/tasks` (含过滤)、`deps <id>` (传递查询)、`rename <old> <new>` |
| **goal-audit** —— audit 规则扩展 | 基础规则 ✓；待做：release_blocked / release_unknown / `audit --release` 过滤 |
| **goal-viz** —— 可视化里 release 维度 | 基础 viz ✓；待做：release 下拉过滤、左侧按 release 分组 |

### 规划中 — 0.6.x → 1.0.0（对应长期目标）

| Goal | 对应长期目标 | 内容 |
|---|---|---|
| **goal-llm-plan** | 第 2 点（全新项目 → DAG） | `vmap plan` 升级：从自由文本 PRD 抽**语义** goal，不只 `- [ ]` checklist |
| **goal-regression-runner** | 第 4 点（每个 goal 都有回归测试集） | 真跑挂在每个 goal 上的测试，挂了就拦发版，并指出是哪个 goal 回归。当前 `audit` 只校验测试**是否被列出**，不验是否通过 |
| **goal-greenfield-bootstrap** | 第 2 点 | 头脑风暴 skills（gstack 等）→ `vmap plan` 的闭环更紧 —— agent 把用户从一句话需求一直带到完整 DAG，不需要手动复制粘贴 |
| **goal-cross-language** | — | Rust / Go / Python 模板（backfill 救援工具广播） |
| **goal-schema-freeze** | — | `schema_version` 字段 + 升级路径 + 稳定 schema 文档 |

### 已交付

| Release | 日期 | 内容 |
|---|---|---|
| **0.1.0** | 2026-05-15 | Live tracking：`init / add goal / add task / update / rm`、JSON 落地、循环检测、稳定退出码契约 |
| **0.2.0** | 2026-05-17 | Plan（checklist + tlist）、Backfill（moonbit / typescript / dotnet 模板）、可视化基础（HTML、product/搜索/状态过滤、节点详情）、Audit 基础（tests / docs / region metadata）、GitHub issue drift 脚本 |
| **0.3.0** | 2026-05-18 | 术语重命名：Milestone → Goal、Issue → Task（和 GitHub 概念隔离） |
| **0.5.0** | 2026-05-19 | 给 coding agent 用的一站式体验：`install.sh`（curl \| bash）+ skills bundle（SKILL.md / cheatsheet / playbooks / vibe-map-bootstrap）+ `.vmap/` 默认路径 + 每次 mutating 命令 auto-render `.vmap/vibe-map.html` + `vmap version` / `vmap upgrade` + cli-dag-mgmt 12 个命令 + release lanes 基础 + node 详情 modal |
| **0.5.1** | 2026-05-19 | Skills 更新：bootstrap 流程里 agent 用 `gh issue list` 把 GitHub issues 当 PRD 信号读 |
| **0.5.2** | 2026-05-20 | 新增 `vmap coverage`（docs / src / issues 覆盖率）+ `vmap doctor`（density / lane / orphan / mismatch 健康度告警）；以 MIT 许可发布到 [mooncakes.io](https://mooncakes.io/docs/eanzhao/vibe-map) |
| **0.5.3** | 2026-05-20 | `vibe-map.html` 前端优化：双击侧栏 goal 行弹出详情 modal、页面上的 GitHub URL 均可点击（新标签打开）、双击展开的任务卡片弹出任务详情 modal |
| **0.6.0** | 2026-05-21 | 发布建模阶段 2、审计阶段 2、可视化阶段 3 与 AI 回归上下文支持：`vmap release status` / `close` 命令行子命令（支持平台特定的 FFI 日期获取）、`vmap audit --release` 过滤支持、核心发布审计规则（`release_unknown` 与 `release_blocked`）、HTML 可视化侧边栏 Release 分组与过滤下拉框，以及 `vmap regression prompt` 子命令（用于汇总生成供 AI 自动修复的 markdown 诊断提示词上下文） |
| **0.6.1** | 2026-05-22 | 回归探针看板与运行器：引入自动化回归运行器 `vmap regression run`（跨平台 FFI 命令运行），HTML 可视化侧栏选项卡切换支持 “回归探针” 状态看板（已通过/已失败/未运行/缺少探针），以及在 `vibe-map.html` 节点详情卡片中渲染详细执行记录与探针警告。 |
| **0.7.1** | 2026-05-23 | 委托 Codex 执行循环：新增 `codex-goal-implement-loop` 与 `codex-architecture-refactor-loop` 两套 playbook、配套 prompt 模板，以及跨平台 `spawn-codex.sh` 包装脚本，让 controller agent 可以把实现 / review / 架构重构交给 Codex CLI，同时继续用 vmap 作为人可见的状态面。 |
| **0.7.2** | 2026-06-03 | 最小 agent 上下文切片：新增 `vmap context <id>`，基于现有 DAG 的 `deps`、`docs`、`tests` 输出确定性的 `{ files, ancestorGoals }` JSON，并为 goal / task 切片补了核心单测。 |


## 贡献

欢迎 issue、fork、PR —— 都在 [github.com/eanzhao/vibe-map](https://github.com/eanzhao/vibe-map) 上。项目是双语（English / 简体中文），用哪种都行。

如果是提一个新方向，建议先开 issue 对一下 —— 长期形态（参见 [长期目标](#长期目标)）是有偏见的，避免你白白返工。

## 构建

[MoonBit](https://www.moonbitlang.com/) 写的：

```bash
moon install                # 拉 moonbitlang/x 依赖
moon build --target native  # 出 _build/native/debug/build/cmd/vmap/vmap.exe
moon test                   # 63 tests
moon fmt && moon check
```

## 许可证

MIT —— 见 [`LICENSE`](LICENSE)。
