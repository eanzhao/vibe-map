# SKILL.md — vmap for coding agents

> 这份文档是给 **coding agent**（Claude Code / Codex / Cursor / 其它）读的。
> 教你怎么用 `vmap` CLI 把项目进展维护成一张可视化 DAG，让用户随时打开 `.vmap/vibe-map.html` 看你写到哪了。

读完这一份就够开始用。具体场景查 `skills/playbooks/`，CLI 速查表查 `skills/cheatsheet.md`。

---

## 你（agent）的工作模式

每次接到一个用户任务，按这个顺序走：

0. **如果项目里还没有 `.vmap/`**——这是**冷启动**场景，先读 `skills/playbooks/bootstrap-existing-codebase.md`，建一份初版 DAG 让用户审视，再继续。**不要默认跑 backfill 就完事**——出来的是 package 镜像不是语义 DAG。
1. **从 PRD/README/issue 提语义 goal**——不是按文件、不是按 package
   - 如果是 GitHub repo（`git remote -v` 含 github.com）且 `gh auth status` ok，**先 `gh issue list --state open`** 扫一眼活的需求作为 PRD 信号
2. **vmap add goal** 加进图，标 `--focus` 表示当前在做；如果来自 issue，把 `--gh-query "is:issue ..."` 和 `--docs "https://github.com/.../issues/N"` 都写上
3. **拆 task** 用 vmap add task，把实现路径写下来（多个文件 / 跨多 package 都没关系）
4. **每完成一步** vmap update --status done（auto-render 会立刻刷新 .vmap/vibe-map.html）
5. **closure 单调推进** 用 vmap update --closure scoped/public/bridged/mature 标"做到哪个阶段了"
6. **关键节点跑 vmap audit**，按 violations 修测试 / 文档 / region metadata
7. **想看全貌**：vmap status / vmap show / vmap list / vmap deps / vmap release list

**核心约束**：用户不会主动开 `.vmap/vibe-map.html`，但他随时可能打开。所以你每次有进展都要 vmap update，让图反映真实状态。否则 vmap 就退化成你写代码的"副本"而不是"共识接口"。

---

## ⚠️ 会话边界：vmap 会话只分析、不改码

当前会话被用来"启用 / 维护 vibe-map"——那么这个会话的产出只有两类：

1. 往 `.vmap/` 里写（JSON、HTML）：跑 `vmap init / add / update / audit / render / release ...`
2. 用自然语言跟用户对齐 goal / task / closure 的语义

**不要修改用户项目里的任何源代码 / 配置 / 测试文件**。哪怕你边读边发现"这一行明显是 bug、顺手改了吧"——不改。理由：

- vmap 维护的是项目的"共识快照"。同一会话里 agent 既分析图又改源代码，会让图和代码同时漂，丢掉"这张图是此刻代码的诚实映射"这个性质。
- 用户后续要复盘"vmap 是不是漏看了什么"时，你已经把现场改过了。

**如果用户在同一会话里同时让你"维护 vmap" + "顺手改一下代码"**，明确告诉他：

> 当前这个会话我建议只用来给项目做 vmap 分析（写 `.vmap/`）。
> 你要改代码的话，开一个新的 session（⌘N / 新建一个 chat），在那边专心改实现；
> 这边 vmap 一直挂着，等你那边改完再回来更新 goal/task 状态。

如果用户坚持"就在这里一起做"，可以做，但**先 commit 一次当前 `.vmap/` 的状态作为基线**，再开始改码，便于事后区分"vmap 视图"和"代码 diff"两个层面的变化。

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

| 场景 | 看这份 |
|---|---|
| **`.vmap/` 还没初始化 + 代码已经一大坨**（冷启动） | `skills/playbooks/bootstrap-existing-codebase.md` |
| 接到一个新需求，要把它放进图 | `skills/playbooks/new-feature.md` |
| audit 报红，按它修 tests / docs | `skills/playbooks/audit-fix-loop.md` |
| 推一个 release 收尾 | `skills/playbooks/release-shipping.md` |
| 用户问"现在做到哪了" | `skills/playbooks/daily-progress.md` |
| 重命名 / 移动 task / 改 deps | `skills/cheatsheet.md` |

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
