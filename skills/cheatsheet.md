# Cheatsheet — vmap CLI

> 给 coding agent 的 CLI 速查表。每条都有用法 + 一行说明 + 关键 flag。

## 数据管理

```bash
# 第一次：自动 mkdir .vmap，打印 gitignore 提示
vmap init --name "项目名"

# 加 goal（语义目标）
vmap add goal --id g-login --title "用户能登录" \
  --closure scoped --owner alice --focus \
  --milestone 0.4.0 \
  --regression-testable \
  --tests src/auth/test.mbt --docs docs/auth.md

# 加 task（实现动作）
vmap add task --id t-auth --goal g-login --title "auth middleware" \
  --regression-testable \
  --deps t-other-task --notes "JWT-based"

# 删
vmap rm <id>          # goal 会连带删它的 task
vmap rm <task-id>     # task 删自己 + 清 deps 引用

# 改 id（自动改所有引用）
vmap rename <old> <new>
```

## update —— 改字段（最常用，分三类）

### 状态 / 文本类
```bash
vmap update <id> --title "新标题"
vmap update <task-id> --status done    # todo | in-progress | blocked | done
vmap update <task-id> --notes "..."    # task 的 notes
vmap update <goal-id> --description "..."  # goal 的 description
vmap update <goal-id> --owner alice
```

### 列表类（替换 vs 增量）
```bash
# 替换整个列表（空串清空）
vmap update <id> --deps a,b,c
vmap update <id> --tests t1,t2
vmap update <id> --docs d1,d2

# 增量（推荐 AI 用，更安全）
vmap update <id> --add-dep a,b
vmap update <id> --remove-dep a
vmap update <id> --add-test src/foo_test.mbt
vmap update <id> --remove-test src/foo_test.mbt
vmap update <id> --add-doc docs/foo.md
vmap update <id> --remove-doc docs/foo.md
```

### 跨结构操作
```bash
# 把 task 移到另一个 goal
vmap update <task-id> --goal <new-goal-id>

# 改 release 归属
vmap update <goal-id> --milestone 0.5.0
```

### region metadata
```bash
vmap update <goal-id> --closure scoped         # 单调推进，不能回退
vmap update <goal-id> --formal checked         # none/sop/checked/audited
vmap update <goal-id> --product default
vmap update <goal-id> --issue-count 3
vmap update <goal-id> --focus / --no-focus
vmap update <goal-id> --archived / --no-archived
vmap update <goal-id> --promoted-at scoped=2026-05-19,public=2026-06-01
vmap update <goal-id> --gh-query "is:issue label:auth"
```

## 查询

```bash
# 总览
vmap status                       # 文本
vmap status --json
vmap status --release 0.4.0       # 只看一个 release

# 单节点详情
vmap show <id>                    # 文本，含 tasks / upstream / downstream
vmap show <id> --json

# 列出（过滤可组合）
vmap list goals
vmap list goals --focus
vmap list goals --release 0.4.0 --closure scoped --owner alice
vmap list goals --no-tests        # audit 准备：找没测试的
vmap list goals --no-docs
vmap list goals --archived
vmap list goals --product default --json

vmap list tasks
vmap list tasks --goal g-login
vmap list tasks --status todo
vmap list tasks --status in-progress --json

# 依赖图
vmap deps <id>                    # 上游 + 下游
vmap deps <id> --upstream
vmap deps <id> --downstream
vmap deps <id> --json
```

## Release（版本边界）

```bash
# 加
vmap release add 0.4.0 \
  --label-en "release modeling + audit" \
  --label-zh "release 维度 + audit" \
  --target 2026-06-15 \
  --status open    # planned | open | closed

# 列
vmap release list
vmap release list --json

# 改字段（状态机校验）
vmap release update 0.4.0 --status open
vmap release update 0.4.0 --target 2026-07-01
vmap release update 0.4.0 --notes "delayed by audit work"

# 分配 / 取消分配
vmap release assign 0.4.0 --goals g-login,g-logout
vmap release unassign 0.4.0 --goals g-login
vmap release unassign 0.4.0          # 不传 --goals 清空所有成员

# 删
vmap release rm 0.4.0                # 有成员会拒绝
vmap release rm 0.4.0 --force        # 先清成员 milestone 再删
```

## 质量守门

```bash
vmap audit                        # 文本，扫所有规则
vmap audit --json                 # JSON，AI loop 友好
# exit 0 = 干净
# exit 3 = 有违例

# 当前规则：
# - missing_tests:  regression_testable=true 但 tests=[]
# - missing_docs:   status != todo 但 docs=[]
# - missing_region_metadata: goal 缺 closure/owner/gh_query/issue_count/focus/archived/promoted_at
```

GitHub 集成（独立脚本）：
```bash
python3 tools/audit_github.py --file .vmap/vibe-map.json
python3 tools/audit_github.py --file .vmap/vibe-map.json --strict
python3 tools/audit_github.py --file .vmap/vibe-map.json --markdown   # 适合 PR comment
```

GitHub issues 当 PRD 来源（需要 `gh` CLI + `gh auth login`）：
```bash
# 判断 + 列 open issues
git remote -v | grep -q github.com && gh issue list --state open --limit 50
gh issue list --state open --label "enhancement"
gh issue list --state open --label "bug"
gh issue list --state open --milestone "v1.0"

# 看具体 issue 的完整对话
gh issue view <number>
gh issue view <number> --comments

# 把 issue 关联进 vmap
vmap add goal --id goal-... --gh-query "is:issue repo:<owner>/<repo> <ref>"
vmap update <task> --add-doc "https://github.com/<owner>/<repo>/issues/<num>"
```

## 防漏检查（bootstrap 后 / 任何时候）

```bash
# 覆盖率：DAG 引用了多少 docs / src 顶层目录 / GH issue
vmap coverage                            # 三个维度总览
vmap coverage --docs-only                # 只看 docs
vmap coverage --code-only                # 只看 src/<dir> 匹配
vmap coverage --issues-only --issues-file /tmp/issues.json
vmap coverage --docs-root README.md,docs # 改 scan 路径
vmap coverage --src-root app/lib         # 改 src 根
vmap coverage --max-examples 100         # 多列点未引用示例
vmap coverage --json                     # AI loop 友好

# issues 维度需要先用 gh 拉数据
gh issue list --state all --limit 500 \
  --json number,title,state,url > /tmp/issues.json
vmap coverage --issues-file /tmp/issues.json

# 健康度告警：density / lane balance / orphan / codebase mismatch
vmap doctor                              # 文本
vmap doctor --json                       # JSON
vmap doctor --scan-root . --src-root src # 覆盖默认扫描路径
# 始终 exit 0（advisory，不阻塞）
```

经验阈值：`vmap coverage` 的 weakest 维度 < 70% → bootstrap 没做完，回 playbook §1.5。

## 救援工具（对老 codebase）

```bash
# backfill：每个 package → 一个 goal，每个源文件 → 一个 done 的 task
# ⚠️ 这是事后追溯工具，不是主入口。新项目走 vmap add goal。
vmap backfill --src . --template moonbit       # 内置: moonbit / typescript / dotnet
vmap backfill --src . --template-file path.json

# plan：从 markdown 抽 checklist
vmap plan --docs ROADMAP.md docs/              # 默认抽 `- [ ]`
vmap plan --docs TODOS.md --format tlist       # 抽 `## T<N> — title` + `**Status:**`
```

## 渲染

```bash
# 自动渲染：每次 mutating 命令后自动写 .vmap/vibe-map.html
# 要跳过（批量场景），加 --no-render

vmap render --out custom.html       # 显式渲染到指定路径

vmap import --in raw.json           # 批量加载（含校验）
vmap import --in raw.json --no-render
vmap backfill --src . --no-render
vmap plan --docs ROADMAP.md --no-render
```

## 退出码

| code | 含义 |
|---|---|
| 0 | 成功 |
| 1 | 业务校验失败（依赖循环、id 重复、未知节点、release 校验失败、UnknownGoal、ReleaseStatusRegression 等） |
| 2 | CLI 参数错误 |
| 3 | `audit` 发现违例 |

## 版本

```bash
vmap --version          # release tag (e.g. v0.5.0-alpha.3) 或 "dev" (本地构建)
vmap version            # 同上，文本形式 `vmap <tag>`
vmap version --json     # {"version": "v0.5.0-alpha.3"}
vmap version --check    # 当前版本 + 检查 GitHub 最新 release 的 curl 命令
vmap upgrade            # 打印一行 curl install.sh，配 `| bash` 一键升级
vmap upgrade | bash     # 实际执行升级（重装 binary + skills）
```

## --json 输出

下面命令都支持 `--json`，便于 AI parse：

- `vmap status --json`
- `vmap show <id> --json`
- `vmap list goals --json`
- `vmap list tasks --json`
- `vmap deps <id> --json`
- `vmap release list --json`
- `vmap audit --json`
- `vmap backfill --json`
- `vmap plan --json`
- `vmap coverage --json`
- `vmap doctor --json`
