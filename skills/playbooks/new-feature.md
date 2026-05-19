# Playbook — 接到一个新需求，怎么放进图

> 用户给你一个 PRD / issue / "帮我做 X" 时的标准动作。

## 1. 抽 goal（语义层）

**先停手 30 秒，读完用户的需求，问自己**：

> 用户感知到的"能力"是什么？

不是问"这要改哪个文件"，是问"用户能多做一件什么事"。

**如果需求来自 GitHub issue** —— 先用 `gh` 拉完整对话，可能比用户口头转述的还全：

```bash
# 用户引用了一个 #号
gh issue view <number>
gh issue view <number> --comments

# 或者去 repo 翻最近 open 的看背景
gh issue list --state open --label enhancement --limit 10
```

让 issue 的 `<number>` 落进 vmap：goal 的 `--gh-query "is:issue repo:owner/repo <ref>"` 或 task 的 `--docs "https://github.com/.../issues/<num>"`。

举例：

| 用户说 | 错的 goal | 对的 goal |
|---|---|---|
| "加一下 GitHub 登录" | `goal-auth-pkg` | `goal-github-oauth-login` |
| "搜索响应太慢，优化一下" | `goal-search-rewrite` | `goal-search-p99-100ms` |
| "做一下 release lanes" | `goal-release-pkg-refactor` | `goal-release-modeling`（版本化 goal 分组） |
| "把 milestone 改成 goal" | `goal-rename-symbols` | `goal-terminology-cleanup`（避免和 GitHub 概念冲突） |

如果一句话讲不清能力是什么，goal 还没想清楚。

## 2. 看现状

```bash
vmap status                    # 当前在做啥
vmap list goals --focus        # 现在的焦点是哪几个
vmap release list              # 这事归哪个 release
```

判断：

- 这个 goal **属于哪个 release**？（没有合适的，先 `vmap release add`）
- 它 **依赖谁**？（前置工作还没做？记在 deps 里）
- 它 **依赖于谁未来的扩展**？（不在 deps 里，但 downstream goal 需要它先做）

## 3. 加 goal

```bash
vmap add goal --id goal-github-oauth-login \
  --title "用户能用 GitHub 登录" \
  --description "PRD 里的 #42，替换现有 email/password 流程" \
  --closure obligation \
  --owner alice \
  --milestone 0.4.0 \
  --focus \
  --regression-testable \
  --gh-query "is:issue label:goal-github-oauth-login" \
  --issue-count 1 \
  --docs docs/auth/oauth.md
```

**字段选取建议**：

- `--closure obligation` —— 接手了。开干前是 `seed`，写完设计文档/RFC 升 `scoped`，对外承诺/release notes 升 `public`，全链路通 + smoke 通 `bridged`，30 天稳定 `mature`
- `--owner` 必填（你就是 owner，写你的名字 / agent 标识）
- `--milestone` 必填（如果项目用 release）
- `--focus` 标记 "当前正在做"，渲染会高亮
- `--regression-testable` 是 audit 的依据，是代码型 goal 就标 true
- `--gh-query` 让 `tools/audit_github.py` 能查 issue 数漂移

## 4. 拆 task

一个 goal 拆成几个 task，每个 task 是**一个可独立 PR 的工作单元**：

```bash
vmap add task --id t-oauth-config \
  --goal goal-github-oauth-login \
  --title "GitHub OAuth client_id / secret 配置 + 环境变量加载" \
  --regression-testable

vmap add task --id t-oauth-init \
  --goal goal-github-oauth-login \
  --title "/auth/github 重定向到 GitHub OAuth" \
  --regression-testable \
  --deps t-oauth-config

vmap add task --id t-oauth-callback \
  --goal goal-github-oauth-login \
  --title "/auth/callback 接收 code，换 token，创建本地 session" \
  --regression-testable \
  --deps t-oauth-init

vmap add task --id t-existing-login-removal \
  --goal goal-github-oauth-login \
  --title "移除旧的 email/password 登录路径 + 数据迁移脚本" \
  --deps t-oauth-callback
```

**拆 task 的判断标准**：

- 一个 task 大约对应**一个 PR / 一个 git commit 串**
- task 之间的 deps 是真依赖（"做完 A 才能做 B"），不是顺序偏好
- task 不必和源文件一一对应——一个 task 可以涉及 3-5 个文件

## 5. 开始做

```bash
vmap update t-oauth-config --status in-progress
# ... 写代码、写测试 ...
vmap update t-oauth-config --status done \
  --add-test src/auth/oauth_config_test.mbt \
  --add-doc docs/auth/env-vars.md
```

每完成一个 task 都跑 `--status done`。auto-render 会刷新 `.vmap/vibe-map.html`，用户随时打开能看到 ✓ 标记。

## 6. 推 goal closure

每过一个阶段，升 closure：

```bash
# 写完所有 task 的 setup + 主路径：
vmap update goal-github-oauth-login --closure scoped \
  --promoted-at scoped=$(date +%Y-%m-%d)

# 已对外发了 release notes / 用户文档：
vmap update goal-github-oauth-login --closure public \
  --promoted-at public=$(date +%Y-%m-%d)

# 上下游都通了 + smoke 测试通过：
vmap update goal-github-oauth-login --closure bridged \
  --promoted-at bridged=$(date +%Y-%m-%d)

# 30 天无 incident：
vmap update goal-github-oauth-login --closure mature \
  --promoted-at mature=$(date +%Y-%m-%d)
```

## 7. audit 守门

每完成一个 goal 跑一次 audit：

```bash
vmap audit --json > /tmp/audit.json
# 如果 exit 3，parse 出 violations，按 kind 修
```

详见 `skills/playbooks/audit-fix-loop.md`。

## 8. 全做完，撤焦点

```bash
vmap update goal-github-oauth-login --no-focus    # 不再是当前焦点
```

如果整个 release 收尾，看 `skills/playbooks/release-shipping.md`。

---

## 反例：错误的 goal 划分

**用户**：帮我加个搜索功能。

**错的做法**：

```bash
vmap add goal --id goal-search-backend --title "Search backend package"
vmap add goal --id goal-search-frontend --title "Search frontend package"
vmap add goal --id goal-search-db --title "Search DB schema"
```

这是按 **技术分层** 拆 goal，不是按用户能力。用户看到这三个不知道什么时候能搜东西。

**对的做法**：

```bash
vmap add goal --id goal-search-mvp --title "用户能搜文档标题" \
  --closure obligation --focus

vmap add task --id t-search-index --goal goal-search-mvp \
  --title "标题字段全文索引 (PostgreSQL tsvector)"
vmap add task --id t-search-api --goal goal-search-mvp \
  --title "/api/search 端点，返回 title + url + snippet"
vmap add task --id t-search-ui --goal goal-search-mvp \
  --title "搜索框组件 + 结果页"
```

一个 goal、三个 task、跨三个 package。**这才是 vibe-map 设计的样子**。
