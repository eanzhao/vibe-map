# Playbook — 从已有代码冷启动

> 用户刚装完 vmap，让你接手一个已有的 codebase（可能很大），项目根还没有 `.vmap/`。
> 你的任务：把它**补**成一张**语义** DAG——不是把代码结构镜像进图。

冷启动是 vmap 最容易跑偏的场景。`vmap backfill --src .` 能快速得到一张图，但它是 **package 镜像**，对用户没有"看进度"的价值。要做对，得花一点工读 PRD + 代码，按用户视角抽 goal。

---

## 1. 先探仓库（30 秒）

```bash
ls -la
cat README.md 2>/dev/null | head -100
ls docs/ 2>/dev/null

# 整体规模 + 主语言
find . -type f \
  -not -path './.git/*' -not -path './node_modules/*' \
  -not -path './_build/*' -not -path './.vmap/*' \
  -not -path './target/*' -not -path './.venv/*' \
  | head -50

# 找所有的 markdown 文档（PRD / 设计 / TODO 候选源）
find . -type f -name "*.md" \
  -not -path './node_modules/*' -not -path './.git/*' | head -30
```

判断：
- 有没有 README / 设计文档？→ 决定走"PRD-rich"还是"PRD-poor"分支
- 主语言是什么？→ 决定 backfill 模板（moonbit / typescript / dotnet，或暂不 backfill）
- 主入口在哪？→ `src/main.*`、`index.*`、`app.*`、`cmd/*/main.*`、`bin/*`

## 1.5 强制全量盘点（盘点完才能进 step 2）

冷启动**漏 goal** 是 vmap 最常见的故障模式——agent 抽样几个文档觉得"够了"，就开始 `vmap add goal`，结果用户事后发现 30%+ 的能力被漏了。

防漏的唯一办法是**先把项目的"全集"显式列出来**，决定每一项是"映射 / 暂略 / 不做"，然后才动手。

```bash
# 全量 markdown 清单（PRD 候选源的全集）
find . -type f -name "*.md" \
  -not -path './.git/*' -not -path './node_modules/*' \
  -not -path './_build/*' -not -path './.vmap/*' \
  -not -path './target/*' -not -path './.venv/*' \
  | tee /tmp/vmap-all-md.txt | wc -l
cat /tmp/vmap-all-md.txt

# 全量 issue 清单（含 closed —— 见 §2.5）
gh issue list --state all --limit 500 \
  --json number,title,state,labels,url > /tmp/vmap-all-issues.json
jq '. | length' /tmp/vmap-all-issues.json

# 顶层 src/ 目录（每个目录可能 = 一类能力）
ls -la src/ src/lib/ 2>/dev/null
```

读这些，给每一项标个意图（"映射 / 暂略 / 不做"）。**不要**只抽几个看着眼熟的。

完成 step 4 后回头跑：

```bash
vmap coverage              # 三个维度的引用率
vmap coverage --json > /tmp/vmap-cov.json
```

**硬门槛**：如果 `weakest` 维度 < 70%，**不要进 step 5（和用户对话），先回 step 2 补抽**。
70% 是经验阈值——低于它通常意味着"你只看了显眼的，没扫到长尾"。这是 vmap v0.6.0 加进来的反漏机制；之前没这个门槛时，200+ docs 的项目漏 30%+ 是常态。

跑 `vmap doctor` 看健康度告警（density / lane balance / orphan / codebase mismatch），把 `codebase_mismatch` 类的告警当**最严重信号**——它直接说"代码里有 foo/ 但 DAG 里没人提 foo"。

## 2. 找 PRD-shaped 信号

> **抽 goal 之前，尽量把项目的文档读完整**——不是抽样 5 分钟就停。冷启动抽出来的 goal 直接决定后续画布的形状，你少读一份设计文档就可能漏一整条语义 lane。
>
> **哪些可以跳过**：在头部、文件名或 README 索引里被明确标注为 `deprecated` / `archived` / `legacy` / `废弃` / `旧版本` / `已弃用` 的文档；属于"对外贡献者指南" / "代码风格"这类**与产品能力无关**的文档；纯生成产物（changelog 摘要、自动生成的 API ref）。其它都该读。
>
> **不确定要不要跳过**：默认读。冷启动的成本主要在抽 goal 的判断，不在读文档；漏读一份设计 doc 后果远大于多读几页。

读这些找"用户能感知的能力"：

| 读什么 | 找什么 |
|---|---|
| `README.md` "Features" / "What it does" / "Usage" / "Quickstart" 段 | 用户视角的能力列表 |
| `docs/`、`design/`、`ARCHITECTURE.md`、`ROADMAP.md` | 设计意图、未做的事 |
| 主入口文件顶部注释 / 模块 docstring | 项目自述 |
| CLI 项目：`<binary> --help` 列出的命令族 | 每条命令 ≈ 一个 user-facing 能力 |
| Web 项目：`routes/`、`pages/`、`controllers/` 的命名 | URL 路径揭示能力 |
| **GitHub Issues**（如果 repo 在 github） | **当前活的需求/痛点；比 README 更新** |

### 如果是 GitHub repo，跑一遍 issues

最常被 vibe-map 漏掉的 PRD 来源——issues 通常代表用户**正在表达的需求**，比静态文档更接近"现在该做什么"。

判断 + 拉取：

```bash
# 是 GitHub repo 吗？
git remote -v | grep -q github.com && echo "yes" || echo "no"

# gh 装了且登录了吗？
gh auth status 2>&1 | head -1

# 拉 open issues（标题 + body 摘要 + labels）
gh issue list --state open --limit 50 --json number,title,labels,body \
  | head -200

# 按标签分组看
gh issue list --state open --label "enhancement" --limit 30
gh issue list --state open --label "bug" --limit 30
gh issue list --state open --milestone "v1.0" --limit 30   # 如果有 milestone

# 已 closed 的也扫一眼（"已交付的能力"反向追溯）—— 见 §2.5
gh issue list --state closed --limit 30
```

如果没装 `gh` 或没登录，跳过这一步并告诉用户："建议装 gh CLI 并登录，issues 是接最 fresh 的 PRD 信号；这次先跳过"。

### 2.5 闭合 issue 也是 PRD 信号（容易被漏）

`--state closed` 的 issue 远不只是"历史记录"。在很多项目里它们承担着**事实上的路线图**职责：

- **拆分痕迹**：一个大 issue 被关闭，因为它"被拆成 #71 / #72 / #73 几个子 issue"。原 issue 就是子 issue 的 PRD 出处。
- **转写痕迹**：issue 被关闭，原因是"内容已经写进 `docs/roadmap.md` / `TODOS.md` / 设计文档"。这种 issue 不能跳。
- **延期痕迹**：v0.X 时讨论过、被打 `won't fix in v0.X` label 然后关闭——下一版的候选 PRD。

**怎么甄别**：

```bash
# 全部 closed issue
gh issue list --state closed --limit 200 \
  --json number,title,state,labels,closedAt,body \
  > /tmp/closed-issues.json

# 看标题里是不是有"拆分 / 转写 / forward-planning"线索
jq -r '.[] | "#\(.number) \(.title)"' /tmp/closed-issues.json | \
  grep -iE "split|拆|move to|转写|moved|roadmap|forward|planning"

# 看 body 里有没有引用某个文档作为转写目的地
jq -r '.[] | select(.body | test("docs/|TODO|ROADMAP"; "i")) | "#\(.number) \(.title)"' \
  /tmp/closed-issues.json
```

把这类 closed issue 当 PRD 信号处理（用上面 §2 同样的规则归到 goal/task），而不是默认跳过。

每条 issue 怎么处理：

| Issue 类型 | 处理 |
|---|---|
| 用户视角的**新能力**（"add support for X"、"希望能 Y"） | 候选 goal。`vmap add goal --id goal-<slug> --gh-query "is:issue <num>"` |
| **bug 修复**（"X 不工作"） | 通常归到现有 goal 下的 task，**不是新 goal**。如果是大 bug 才单独抽 |
| **内部重构 / 技术债** | 不抽 goal。AI 可以 `vmap add task` 在某 goal 下，或者标 `--notes` 提一句 |
| **问问题 / 求助** | 跳过，不是 PRD |
| **重复或已实现** | 跳过 |

把 issue 编号带进 vmap：

```bash
# 单个 issue 落到 goal
vmap add goal --id goal-graphql-api \
  --title "用户能用 GraphQL 查询数据" \
  --description "原始需求：#42 + #51" \
  --gh-query "is:issue repo:owner/repo label:graphql" \
  --issue-count 2 \
  --closure obligation \
  --owner alice

# 已有 goal，issue 作为 task
vmap add task --id t-fix-pagination-bug \
  --goal goal-graphql-api \
  --title "修分页 bug (#73)" \
  --docs "https://github.com/owner/repo/issues/73"
```

`--gh-query` 字段后续会被 `tools/audit_github.py` 用来检查 issue 数漂移——和 release 的 closed/open 状态对得上。

**代码层面可以快速跳过**（实现细节，不是 PRD 信号）：
- 实现细节文件（`utils/`、`helpers/`、`internal/`、`_lib/`）
- 测试文件
- 配置 / build 脚本

但是**文档层面要尽量读完**——README、docs/、design/、ROADMAP、ARCHITECTURE、CHANGELOG、顶层 module docstring。只跳过被明确标注 `deprecated` / `archived` / `legacy` / `废弃` 的文档，以及"贡献者指南 / 代码风格"这类与产品能力无关的文档。

目标：抽出 5-15 个高质量的语义 goal 草稿。读文档花在前期，比抽错了再 rename 便宜。

### 3.5 平台基建也是 goal（不只是"用户能感知的能力"）

vmap 的核心定义是 "goal = 用户能感知的能力"，但在 LLM-native / 异步任务驱动 / 多模态等项目里，有一类**用户感知不到、但失败就崩**的基础设施。它们必须进 DAG，否则一旦挂掉没人知道是谁在维护：

- **LLM 调用池 / 限流 / 重试** —— 没 goal → 没 owner → 没人盯 cost / failure rate
- **图片 / 音频 / 视频流水线**（上传 → 处理 → 存 → CDN）—— 没 goal → 数据丢了不知道哪一步漏
- **异步任务系统 / 定时任务 / 队列** —— 没 goal → 一个 job 卡住没人发现
- **观测 / 日志 / metrics 接入** —— 没 goal → 出事后只能 git blame
- **数据迁移 / schema 版本** —— 没 goal → 升级时漏字段

这类 goal 的命名规范——**用 `goal-infra-*` 或 `goal-*-platform` 前缀**，与"用户感知能力" goal 视觉区分：

```bash
vmap add goal --id goal-infra-llm-pool \
  --title "LLM 调用池（多 provider / 限流 / cost 上限）" \
  --description "所有 LLM-driven feature 的共享依赖；挂了 N 个 goal 受影响" \
  --closure scoped \
  --owner alice \
  --product infra

vmap add goal --id goal-infra-image-pipeline \
  --title "图片上传 → 处理 → CDN 流水线" \
  --closure scoped --owner bob --product infra

vmap add goal --id goal-infra-narrative-jobs \
  --title "异步剧情生成 jobs（队列 + 失败重放）" \
  --closure obligation --owner alice --product infra
```

辨别一个 candidate 应该是 platform goal 还是普通能力 goal：

| 问题 | 答 yes → platform goal |
|---|---|
| 至少 3 个其它 goal 依赖它吗？ | 是 |
| 它挂了，多个用户能力同时不可用吗？ | 是 |
| 它在 codebase 里通常以 "shared" / "common" / "infra" / "core" 出现吗？ | 是 |

**`vmap doctor` 会用 `goal-infra-*` 命名约定来计算"如果它挂了，N 个 goal 受影响"**（实现在 round 2）。

## 3. 决策分支

### A. PRD-rich（README/docs 里说清楚做啥用）

跳过 backfill，直接手工 add：

```bash
vmap init --name "<项目名>"

# 如果 README 有 checklist 风格 todo / 设计文档有 - [ ] 项
vmap plan --docs README.md docs/

# 主要靠自己读 README/docs 抽 goal
vmap add goal --id goal-<feature-1> \
  --title "用户能 X" \
  --description "<from README/PRD>" \
  --closure scoped \
  --focus

vmap add goal --id goal-<feature-2> \
  --title "用户能 Y" \
  --deps goal-<feature-1>
# ...
```

抽 goal 时**反复问自己**：

- "这是 PRD 上的一条**用户能感知的能力**吗？" → 是 → goal
- "这是为了实现某个 PRD 条目而做的**子步骤**吗？" → 是 → task
- "这是**技术分层 / 代码包**？" → **不是 goal**，跳过或归到某 task 里

### B. PRD-poor（代码大但没像样的 PRD）

这是最难的情况。走"backfill 拿骨架 → 语义化重塑"：

```bash
vmap init --name "<项目名>"

# 拿代码 shape 做骨架
vmap backfill --src . --template <moonbit|typescript|dotnet>
# 输出大概是 pkg-auth / pkg-core / pkg-cli / ... 一堆 done 的 task
# ⚠️ 这只是脚手架。下面要把它"语义化"。
```

然后**逐个 `pkg-*` 审视，把它转成 PRD 视角**：

```bash
vmap list goals --json
# 对每一个 pkg-* goal 做：
```

对每个 `pkg-*` goal，按下面三选一处理：

#### 3.B.i 能讲清楚"用户用这个 package 做什么"

直接 rename：

```bash
# 读 2-3 个主要文件
ls src/auth/ ; head -50 src/auth/*.ts

# 决定语义名
vmap rename pkg-auth goal-github-login   # 比如这个 auth 包就是做 GitHub OAuth 登录
vmap update goal-github-login --title "用户能用 GitHub 登录"
vmap update goal-github-login --description "<一句话从代码读出的意图>"
```

#### 3.B.ii 是多个能力的集合

保留原 `pkg-*` 当"实现层 goal"，**新建几个语义 goal**指向它：

```bash
# pkg-core 实现了 audit / parser / store 三个能力
vmap update pkg-core --archived   # 实现细节淡化

vmap add goal --id goal-quality-audit \
  --title "质量守门（tests / docs / region metadata）" \
  --deps pkg-core
vmap add goal --id goal-config-parser \
  --title "用户能配置项目通过 yaml" \
  --deps pkg-core

# 把 task 跨 goal 重分配
vmap update task-audit-rules --goal goal-quality-audit
vmap update task-yaml-parser --goal goal-config-parser
```

#### 3.B.iii 是纯实现细节（utils / shared / internal）

淡化掉，不让它占画布：

```bash
vmap update pkg-utils --archived
vmap update pkg-shared --archived
```

archived goal 在可视化里淡入背景，但数据保留。

## 4. 找漏掉的能力

backfill 不知道的：**未实现但被规划的能力**。从下面找：

```bash
# README / 设计文档里的路线图
vmap plan --docs README.md docs/ROADMAP.md

# TODO 注释（不是每条都该是 goal，挑用户可感知的）
grep -rn "TODO\|FIXME\|XXX" --include="*.<ext>" -- . | head -30

# 已有的 GitHub Issues（如果 step 2 还没扫过）
gh issue list --state open --limit 30
gh issue list --state open --label "good first issue"
```

如果 step 2 已经过了 issues，这里只补"step 2 时不确定要不要抽 goal 的边角"。

新发现的能力，补成 `vmap add goal`：
- 还没开干：`--closure seed`
- 已认领：`--closure obligation`
- 设计完了：`--closure scoped`

## 5. 和用户对一遍（关键！）

冷启动最容易**自信地错**。做完一遍后**主动让用户审视**——但**先用 vmap 自己验一下覆盖率**，不要让用户帮你 review 时才发现你漏了一半。

```bash
# 第一道关：覆盖率门槛
vmap coverage
# 如果 weakest < 70%，回 §1.5 / §2 / §3.5 补抽——不要进对用户那一步
vmap coverage --json > /tmp/vmap-coverage-before-review.json

# 第二道关：健康度告警
vmap doctor
# 重点看：
#   ! codebase_mismatch  → 代码里有 foo/ 但 DAG 没人提，加 goal-foo 或解释为什么不加
#   ! lane_imbalance     → 某 release 太重，考虑拆 0.X.a / 0.X.b
#   i orphan_goal        → 这个 goal 没 downstream，确认是叶子能力还是漏 dep

# 一份草稿
vmap status > /tmp/draft.txt
vmap list goals --json > /tmp/goals.json
vmap render --out .vmap/vibe-map.html
```

具体话术对用户说：

> 我从代码 + README 扫了一遍，抽了 N 个 goal。打开 `.vmap/vibe-map.html` 看一眼。重点确认：
>
> 1. 哪些"goal"其实是**代码分层**、不是用户能感知的能力？（应该 archive 或重新拆）
> 2. 哪些用户能力**我漏了**？（你脑子里有但 README 没写、代码里也不显眼的）
> 3. 哪些应该**合并**或**拆开**？
> 4. release lane 怎么划？

**等用户回馈再继续**。冷启动后立刻进入"加新功能"模式是常见错误。

## 6. 设 release lanes

抽完 goal 后，至少加 2 个 release：

```bash
# 历史 / 当前 / 计划，按项目实际情况
vmap release add 0.X.0 \
  --status closed \
  --closed-at $(date +%Y-%m-%d) \
  --label-en "current state" \
  --label-zh "现状归档"
# (历史已发功能归这里)

vmap release add 0.Y.0 \
  --status open \
  --label-en "current iteration" \
  --label-zh "当前迭代"
# (in-flight goal 归这里)

vmap release add 0.Z.0 \
  --status planned \
  --label-en "next" \
  --label-zh "下一版"
# (seed / obligation 的 goal 归这里)
```

`vmap release assign` 批量归类：

```bash
vmap release assign 0.X.0 --goals goal-already-shipped-1,goal-already-shipped-2
vmap release assign 0.Y.0 --goals goal-in-progress-1
vmap release assign 0.Z.0 --goals goal-planned-1,goal-planned-2
```

## 7. 跑 audit（但别一次修完）

```bash
vmap audit
# 冷启动后通常报很多 missing_tests / missing_docs / missing_region_metadata
```

**不要试图全修**——历史代码缺测试是常态。优先修：

1. **in-flight goal**（`--focus` 的、`milestone=<current-release>` 的）—— 修测试 / 文档
2. **scoped 及以上的 goal**—— 至少补 region metadata（owner / gh_query）

archived / 历史 goal 可以接受 audit 红——它们就是事后追溯。

详见 `audit-fix-loop.md`。

---

## 反例（每一条都见过）

❌ **直接 `vmap backfill` 然后停下** —— 出来的是 package 镜像，用户看了会觉得"这不就是文件树吗"。一定要做 step 3 的语义化重塑。

❌ **从一个文件名脑补一个 goal**：看到 `pkg-payment` 就 add `goal-payment`，不深入读代码。语义 goal 的 title 要是**用户视角的能力**（"用户能用支付宝付款"），不是模块名（"payment service"）。

❌ **抽太细**：100 行的小 utility 不是 goal，是 task 或者另一个 goal 的 notes。

❌ **不和用户对** —— 冷启动错很正常，不让人 review 就提交是把噪音永久留下。

❌ **把 README 里的"安装步骤"也抽成 goal** —— 安装是开发者动作不是用户能力。

---

## 时间预算

| 仓库规模 | 目标抽出 goal 数 | 预期耗时 |
|---|---|---|
| 小（< 50 文件） | 3-8 | 10-15 min |
| 中（50-300 文件） | 8-15 | 20-40 min |
| 大（> 300 文件） | 15-25 | 1-2 hr（分多次，每次 30 min） |

**别一次性把所有 task 都建出来**。先建 goal + 当前 in-flight 的几个 task，剩下随着工作推进 `vmap add task`。

---

## 待来的工具（不阻塞当前 playbook）

未来 `vmap discover`（round 2）做出来后，理想流程是：

```bash
vmap discover --docs --issues --codebase
# 喂 LLM 同时扫所有 markdown + closed/open issue + src/ 顶层目录，输出
# candidate goal 列表（带 confidence + source 引用 + 与现有 goal 的 overlap 警告）
# vmap discover --apply 一键吸收，vmap discover --review 进交互筛选
```

目前 step 2 / 3.5 还是 manual——`vmap coverage` 和 `vmap doctor` 是反漏的兜底，但不能代替人读文档。**如果你（AI agent）跑完这个 playbook 后觉得有些步骤可以更自动化**，记下来给项目 owner —— 这是 vmap 自身的 product feedback。
