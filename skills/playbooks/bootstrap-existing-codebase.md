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

## 2. 找 PRD-shaped 信号

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

# 已 closed 的也扫一眼（"已交付的能力"反向追溯）
gh issue list --state closed --limit 30
```

如果没装 `gh` 或没登录，跳过这一步并告诉用户："建议装 gh CLI 并登录，issues 是接最 fresh 的 PRD 信号；这次先跳过"。

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

**快速跳过**（这一步别陷进去）：
- 实现细节文件（`utils/`、`helpers/`、`internal/`、`_lib/`）
- 测试文件
- 配置 / build 脚本

时间盒：探仓 + 读关键文档应该在 5-10 分钟内做完。**别把"读完整个 codebase"当目标**——目标是抽出 5-15 个语义 goal 的草稿。

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

冷启动最容易**自信地错**。做完一遍后**主动让用户审视**：

```bash
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

未来 `goal-llm-plan`（1.0 计划）做出来后，理想流程是：

```bash
vmap discover   # 假设的命令，目前不存在
# 自动跑 backfill + plan + 喂 LLM 抽语义 goal proposals
# 输出："suggested goals + which pkg-* to archive + which TODOs to promote"
```

目前这一切都是 manual。**如果你（AI agent）跑完这个 playbook 后觉得有些步骤可以更自动化**，记下来给项目 owner —— 这是 vmap 自身的 product feedback。
