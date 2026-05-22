# SKILL.md — vmap for coding agents

> 这份文档是给 **coding agent**（Claude Code / Codex / Cursor / 其它）读的。
> 教你怎么用 `vmap` CLI 把项目进展维护成一张可视化 DAG，让用户随时打开 `.vmap/vibe-map.html` 看你写到哪了。

读完这一份就够开始用。具体场景查 `skills/playbooks/`，CLI 速查表查 `skills/cheatsheet.md`。

---

## 你（agent）的两种工作模式

vmap 是个**双向接口**：

- **维护模式**：你读代码 / PRD → 写进 `.vmap/`（让图反映现状）
- **实现模式**：你读 `.vmap/` → 写代码（按图施工）

每次接到任务，先判断自己在哪一种。两种模式的核心动作不一样，下面分开列。

### 维护模式 — 让图反映现状

接到"加 / 改 / 整理 DAG"的任务，按这个顺序走：

0. **如果项目里还没有 `.vmap/`**——这是**冷启动**场景，先读 `skills/playbooks/bootstrap-existing-codebase.md`，建一份初版 DAG 让用户审视，再继续。**不要默认跑 backfill 就完事**——出来的是 package 镜像不是语义 DAG。
1. **从 PRD/README/issue 提语义 goal**——不是按文件、不是按 package
   - 如果是 GitHub repo（`git remote -v` 含 github.com）且 `gh auth status` ok，**先 `gh issue list --state open`** 扫一眼活的需求作为 PRD 信号
2. **vmap add goal** 加进图，标 `--focus` 表示当前在做；如果来自 issue，把 `--gh-query "is:issue ..."` 和 `--docs "https://github.com/.../issues/N"` 都写上
3. **拆 task** 用 vmap add task，把实现路径写下来（多个文件 / 跨多 package 都没关系）
4. **每完成一步** vmap update --status done（auto-render 会立刻刷新 .vmap/vibe-map.html）
5. **closure 单调推进** 用 vmap update --closure scoped/public/bridged/mature 标"做到哪个阶段了"
6. **关键节点跑 vmap audit**，按 violations 修测试 / 文档 / region metadata
7. **想看全貌**：vmap status / vmap show / vmap list / vmap deps / vmap release list

**维护模式核心约束**：用户不会主动开 `.vmap/vibe-map.html`，但他随时可能打开。所以你每次有进展都要 vmap update，让图反映真实状态。否则 vmap 就退化成你写代码的"副本"而不是"共识接口"。

### 实现模式 — 拿 DAG 当 reading list / 工作队列

接到"实现 X / 推进 focus goal / 把 todo task 做掉"的任务，**先看图再下笔**。DAG 里 `docs` / `tests` / `--gh-query` / `--add-doc <issue URL>` 已经把"这件事要读哪些规格、跑哪些测试"都记下来了。流程：

1. **挑下一个 task**：`vmap list tasks --goal <focus-goal> --status todo`，按 deps 选一个上游已 done 的
2. **读它链了什么**：`vmap show <task-id>` 看 `docs` / `tests` 列表，**全读进 context**——源文件、issue URL、ADR / RFC 都算
3. **跑现有 tests 当基线**：知道现在什么过、什么不过
4. **标 in-progress**：`vmap update <task-id> --status in-progress`
5. **写代码 + 测试**
6. **回写**：`vmap update <task-id> --status done --add-test <new test> --add-doc <new doc>`
7. **回 step 1**，直到 focus goal 的 task 全 done

详见 `skills/playbooks/implement-from-dag.md`。

**实现模式核心约束**：**不要绕过 DAG 去问用户"接下来做什么"**。如果 `vmap list tasks --status todo` 给的结果不对（task 拆得太粗 / docs 没写 / deps 错了），说明 DAG 漂了——切回维护模式补图，再回来实现。别凭印象选下一个 task。

---

## ⚠️ 会话边界：一次只在一种模式里

两种模式**别在同一会话里来回切**。理由：

- **维护模式里顺手改码**：会让图和代码同时漂，丢掉"这张图是此刻代码的诚实映射"。用户后续复盘"vmap 是不是漏看了什么"时，你已经把现场改过了。
- **实现模式里顺手重建 DAG**：边写边改 goal / task 结构 = 一边设计一边实现，scope 会无控制地扩张。实现模式允许 `vmap update --status` / `--add-test` / `--add-doc` 这些**状态回写**，但**别加新 goal / 拆 task / 改 deps**——那是维护模式的事。

**如果实现模式中途发现 DAG 错了**（task 拆得不对 / docs 漏了 / deps 反了），**停下来切回维护模式**，告诉用户：

> 实现到一半我发现 DAG 漂了（具体...）。建议先停下来补图，再继续实现。
> 你可以现在切到维护视角（哪怕同一会话），我们把 task / docs / deps 修对，再回来做。

**如果用户在同一会话里同时让你"维护 vmap" + "顺手改一下代码"**，明确告诉他：

> 这两件事建议分开会话做。当前这个会话我用来 {维护 / 实现} vmap；
> 另一件事开一个新的 session（⌘N / 新建一个 chat）专做，这边可以一直挂着，等你那边告一段落再回来同步。

如果用户坚持"就在这里一起做"，可以做，但**先 commit 一次当前 `.vmap/` 的状态作为基线**，再开始混着干，便于事后区分"图的变化"和"代码的变化"。

**例外：用户明确要求 Codex CLI 委托循环**。这时当前会话是第三种 **controller 模式**：当前 agent 不亲手写 production code，只负责维护 vmap、派 `codex exec` 子进程、验收和回写状态。按下面的 Codex CLI playbook 做，不按普通维护/实现会话混着做。

---

## 心智模型

### goal vs task vs release

| 概念 | 是什么 | 例子 | 写谁的视角 |
|---|---|---|---|
| **goal** | PRD 里的一条**语义目标** / 用户能感知的能力 | "用户能用 GitHub 登录"、"支持 release 维度" | 产品用户 |
| **task** | 实现这个 goal 需要做的**具体动作** | "写 OAuth callback handler"、"加 session cookie" | 开发者 |
| **release** | 版本边界（"这一版打算交付什么"） | `0.4.0` `1.0.0` | 项目负责人 |

> ⚠️ **goal 不是 package**。如果你忍不住把代码包当 goal（"core 包"、"auth 包"），停下来。重新读 PRD，问"用户能感知什么"，那才是 goal。
>
> 一个 goal 的 task 经常**跨多个源文件 / package**；一个 package 也经常**实现多个 goal**。

### closure 阶段（单调推进，不能后退）

| 阶段 | 含义 | 典型触发 |
|---|---|---|
| `seed` | 提出来了 | issue / discussion 创建 |
| `obligation` | 接手了 | assignee 字段非空 |
| `scoped` | 设计完了 | RFC / ADR / 设计 doc merged |
| `public` | 承诺要发了 | release notes 已发 |
| `bridged` | 上下游都通了 | 上下游 issue closed + smoke 通过 |
| `mature` | 运行稳定 | 30 天无 incident |

每完成一个阶段调 `vmap update <goal-id> --closure <next>`，**不能往回退**（vmap 会拒绝）。

### release 状态机（也是单调）

```
planned → open → closed
```

`closed → open` 会被 vmap 拒绝（`ReleaseStatusRegression`）。

### 依赖（deps）

- `goal.deps` 指向其它 goal（语义层"做 X 之前要做 Y"）
- `task.deps` 指向同一 goal 下的其它 task（"这个先于那个做"）
- **不能跨层**（goal 不能 depend on task）
- vmap 自动跑循环检测，有环就拒绝

---

## 数据约定

- **数据文件**：`.vmap/vibe-map.json`（vmap 默认就读这里，不需要传 --file）
- **渲染**：`.vmap/vibe-map.html`（每次 mutating 命令后**自动刷新**，用户随时打开看）
- **`.vmap/` 应该加进 `.gitignore`**——它是本地工作状态，不进版本
- **第一次用** `vmap init` 会自动 mkdir `.vmap/` 并打印 gitignore 提示

如果用户的项目还没有 `.vmap/vibe-map.json`，直接 `vmap init --name "项目名"`，然后开始用。

---

## 常用工作流（playbooks）

| 场景 | 模式 | 看这份 |
|---|---|---|
| **`.vmap/` 还没初始化 + 代码已经一大坨**（冷启动） | 维护 | `skills/playbooks/bootstrap-existing-codebase.md` |
| 接到一个新需求，要把它放进图 | 维护 | `skills/playbooks/new-feature.md` |
| **图已经有了，按图把 todo task 一个个做掉** | 实现 | `skills/playbooks/implement-from-dag.md` |
| 让当前 agent 调用 Codex CLI 按 DAG 实现 task | 实现 | `skills/playbooks/codex-goal-implement-loop.md` |
| 让 Codex CLI 按 AGENTS.md / CLAUDE.md 持续重构 | 维护 + 实现 | `skills/playbooks/codex-architecture-refactor-loop.md` |
| audit 报红，按它修 tests / docs | 维护 | `skills/playbooks/audit-fix-loop.md` |
| 推一个 release 收尾 | 维护 | `skills/playbooks/release-shipping.md` |
| 用户问"现在做到哪了" | 维护 | `skills/playbooks/daily-progress.md` |
| 重命名 / 移动 task / 改 deps | 维护 | `skills/cheatsheet.md` |

## Codex CLI 委托循环

如果用户明确说“用 Codex CLI 跑”“让 Codex 实现”“无人值守重构”“按 AGENTS.md/CLAUDE.md 反复整理架构”，当前 agent 进入 **controller 模式**：

1. **vmap 负责队列和状态**：从 focus goal / todo task 选工作，所有 phase 变化用 `vmap update` 回写。
2. **Codex 子进程负责改代码**：用 `codex exec --cd <worktree> ...` 派实现、修复、审计或 review；controller 不亲手改 production code。
3. **项目规则随 prompt 下发**：把 `AGENTS.md`、`CLAUDE.md`、目录内更近的 AGENTS、架构文档、CI guard 一起作为约束交给 Codex。
4. **验收独立完成**：controller 检查 diff、summary marker、测试、`codex exec review` 或等价 review，再决定 done / rework / blocked。
5. **状态必须可见**：本地 loop log 只是细节；用户看的 `.vmap/vibe-map.html` 必须同步显示 running / done / blocked。

两种入口：

- **按目标实现**：读 `skills/playbooks/codex-goal-implement-loop.md`。适合“把这个 goal/task 做完”。
- **按架构原则重构**：读 `skills/playbooks/codex-architecture-refactor-loop.md`。适合“按 AGENTS.md / CLAUDE.md 找架构违例并持续修”。

## 防漏（v0.6.0 加入）

`vmap coverage` 和 `vmap doctor` 是 bootstrap 之后的两道防漏关，也可以**随时跑**来检查 DAG 是不是和真实项目脱节了：

```bash
# 覆盖率：DAG 里 docs / src / issues 有多大比例被引用
vmap coverage              # 全部三个维度
vmap coverage --docs-only  # 只看 docs
vmap coverage --json       # AI loop 友好

# 用 gh issue 数据扩展 issues 维度
gh issue list --state all --limit 500 \
  --json number,title,state,url > /tmp/issues.json
vmap coverage --issues-file /tmp/issues.json

# 健康度告警：density / lane balance / orphan / codebase mismatch
vmap doctor
vmap doctor --json
```

**经验阈值**：bootstrap 后 `vmap coverage` 的 weakest 维度应该 ≥ 70%。低于这个值通常意味着 DAG 漏了主要能力——回 bootstrap-existing-codebase.md §1.5 / §2.5 / §3.5 补抽，不要急着进"和用户对话"那一步。

## 升级 vmap

每次开新会话或者用户提到 "vmap 用了一段时间了 / vmap 是不是旧了" 的时候，主动跑一下：

```bash
vmap version --check
# 打印当前版本 + 一行 curl 检查最新 tag。把它跑出来对比：
curl -fsSL https://api.github.com/repos/eanzhao/vibe-map/releases/latest | grep -m1 tag_name | cut -d'"' -f4
```

如果 GitHub 上的 tag 比本地 `vmap version` 报的高，提议升级：

```bash
vmap upgrade | bash
# 等价于：curl -fsSL https://.../master/install.sh | bash
```

升级完 binary + skills 一起更新（同 tarball 发）。所以"升级 vmap" = "升级 skills"，不会出现 binary 新 / skills 老的不同步。

---

## 一些"会让 vmap 失去意义"的反模式

1. ❌ **按 package 加 goal**（`pkg-core` / `pkg-auth`）—— goal 是 PRD 概念，不是代码结构。除非你在用 `vmap backfill` 做老 codebase 救援。
2. ❌ **加完 goal 就不再 update closure** —— closure 是用户看进度的主要信号
3. ❌ **task 永远停在 todo** —— 至少 in-progress 一下，让人看到你在做啥
4. ❌ **不跑 audit** —— audit 是"这工作真的做完了吗"的客观信号
5. ❌ **不分 release 就一直 add** —— 没有版本边界，scope 会无限漂移
6. ❌ **加 milestone 字段填非 release key 的字符串** —— vmap 当前软校验，但 audit 会发 `release_unknown` 警告
7. ❌ **手改 .vmap/vibe-map.json** —— 用 vmap CLI 改，自动跑循环检测、状态机校验、auto-render

### Bootstrap 专属反模式（v0.6.0 加入）

8. ❌ **bootstrap 跳过覆盖率验证** —— 抽完 goal 不跑 `vmap coverage` / `vmap doctor` 就直接和用户对，相当于裸眼检漏。playbook §1.5 把 70% 设成硬门槛；低于这个值就回头补抽。
9. ❌ **"alpha 已实装的能力不用入图"** —— 如果代码已存在但 DAG 里没有对应 goal，这张图就在误导后加入的工程师。`vmap coverage --code` 和 `vmap doctor` 的 `codebase_mismatch` 告警就是给这种情况兜底的——出现 warning 必须处理（加 goal、或者解释"这是 utility 不是能力"并 archive 对应代码）。
10. ❌ **只看 open issue / 跳过 closed issue** —— closed issue 经常承担**事实上的路线图**职责（拆分痕迹 / 转写到 docs / 延期标签）。bootstrap playbook §2.5 强制要求扫 `--state all`。

---

## 退出码契约（agent 在 loop 里靠这个判定）

| code | 含义 | 你应该做啥 |
|---|---|---|
| 0 | 成功 | 继续 |
| 1 | 业务校验失败（循环、id 重复、未知节点、release 校验失败等） | 读 stderr 错误信息，修参数重试 |
| 2 | CLI 参数错误 | 你拼错了 flag，检查 --help |
| 3 | `audit` 发现违例 | 按 violations 修 tests / docs / metadata，再 audit |

所有命令都有 `--json` 输出，喂给你 parse 用。

---

## 一个 5 分钟 quickstart

```bash
# 在用户的项目根目录
vmap init --name "我的项目"

# 加第一个 goal（从 PRD 抽出来）
vmap add goal --id g-login \
  --title "用户能用 GitHub 登录" \
  --closure scoped \
  --owner alice \
  --focus

# 拆 task
vmap add task --id t-oauth-init --goal g-login \
  --title "OAuth init endpoint" --regression-testable
vmap add task --id t-oauth-callback --goal g-login \
  --title "OAuth callback handler" --regression-testable \
  --deps t-oauth-init

# 开始做、记进展
vmap update t-oauth-init --status in-progress
# ... 写代码 ...
vmap update t-oauth-init --status done \
  --add-test "src/auth/oauth_test.mbt"

# 看现状
vmap status
vmap show g-login

# 推到 public
vmap update g-login --closure public

# 跑 audit
vmap audit
# 如果报 missing_docs，补上
vmap update g-login --add-doc "docs/auth.md"
vmap audit
# 直到 exit 0
```

用户打开 `.vmap/vibe-map.html` 就看得到上面这一切的可视化。

---

下一步：读 `skills/playbooks/new-feature.md` 学完整流程，或者 `skills/cheatsheet.md` 当快查表。
