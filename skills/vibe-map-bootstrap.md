# Agent bootstrap prompt

> 用户复制这一段，发给 Claude Code / Codex / Cursor / 任何 coding agent。
>
> 一旦发出去，agent 就能装上 vmap、读懂工作模式、开始在当前项目里维护 vibe-map DAG。

---

```
请在当前项目里用 vibe-map 帮我推进工作。

1. 安装 vmap CLI（如果还没装）：

   curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh | bash

   这一步会下载 vmap 二进制到 ~/.local/bin/，把 skills 放到 ~/.vmap/skills/。
   如果 ~/.local/bin 不在 $PATH，安装脚本会提示加。

2. 读完这份指南，理解 vmap 的工作模式：

   cat ~/.vmap/skills/SKILL.md
   ls ~/.vmap/skills/playbooks/

3. 在当前项目根目录初始化 vmap（如果 .vmap/ 还不存在）：

   vmap init --name "<我的项目名>"

   init 会自动 mkdir .vmap/ 并提示把 .vmap/ 加进 .gitignore。

4. 从这里开始，每个进展都用 vmap CLI 记下来：

   - 接到新需求 → vmap add goal（按语义/PRD 视角，不是按 package！）
   - 拆实现路径 → vmap add task
   - 每完成一步 → vmap update <id> --status done
   - 阶段推进 → vmap update <goal> --closure scoped/public/bridged/mature
   - 关键节点 → vmap audit（违例按规则补 tests / docs / region metadata）
   - 收 release → vmap release update <key> --status closed

   每次 mutating 命令后 .vmap/vibe-map.html 会自动刷新，我会随时打开看图。

5. 具体动作按 ~/.vmap/skills/playbooks/ 下的 playbook 来：

   - new-feature.md       接到新需求怎么放进图
   - audit-fix-loop.md     audit 报红怎么自动修
   - codex-goal-implement-loop.md        用 Codex CLI 按 DAG 实现 task
   - codex-architecture-refactor-loop.md 用 Codex CLI 按 AGENTS.md / CLAUDE.md 做架构重构
   - release-shipping.md   release 收尾怎么走
   - daily-progress.md     我问"做到哪了"时怎么回我

   CLI 速查表 ~/.vmap/skills/cheatsheet.md。

约束：

- **当前这个会话只做 vmap 分析，不要改我的源代码**。你的产出只能是往 .vmap/ 写（JSON / HTML），跑 vmap 命令，和我用自然语言对齐 goal/task。如果你边读边想"顺手把这个 bug 改了"——停下，告诉我，让我新开一个 session 改代码。理由：vmap 是项目当下状态的诚实快照，同一会话里又分析又改码会让快照和代码同时漂，事后没法复盘。如果我执意要在这个会话里也改代码，先 commit 一次 .vmap/ 当基线再继续。
- **抽 goal 之前尽量把项目文档读完整**（README / docs/ / design/ / ROADMAP / ARCHITECTURE / 顶层 module docstring）。只跳过被明确标注 deprecated / archived / legacy / 废弃 的文档，以及贡献者指南那类与产品能力无关的内容。其它默认读完，再开始抽 goal。
- goal 是 PRD 上的"用户能感知的能力"，不是代码 package（不要给我建 pkg-xxx 风格的 goal）
- closure 单调推进（seed → obligation → scoped → public → bridged → mature），不能回退
- 不要手改 .vmap/vibe-map.json，所有改动走 vmap CLI（自动跑循环检测、状态机校验、auto-render）
- 退出码 1 = 业务错误，3 = audit 有违例，按错误信息修

go.
```

---

## 给中文用户的版本

```
帮我用 vibe-map（vmap）维护这个项目的进度。

第一次的话：
1. 装 vmap：curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh | bash
2. 读懂规则：cat ~/.vmap/skills/SKILL.md
3. 初始化：vmap init --name "我的项目"（把 .vmap/ 加 .gitignore）

每次工作时：
- 我说一个需求 → 你按 PRD 视角抽 goal（不是按代码包！），vmap add goal
- 拆成几个 task，vmap add task --deps ...
- 写完一个 task → vmap update --status done
- 整个 goal 推到一个阶段 → vmap update --closure ...
- 关键节点 → vmap audit，按违例修 tests/docs

两条硬约束：
- 当前这个会话**只做 vmap 分析、不改我的源代码**。要改代码请提醒我新开一个 session，那边专心改实现，这边一直挂着记进度。如果我执意要在同一会话里既分析又改码，先 commit 一次 .vmap/ 当基线再说。
- 冷启动抽 goal 之前，**尽量把项目文档读完整**（README、docs/、design/、ROADMAP、ARCHITECTURE 等）。只跳过明确标注废弃 / deprecated / archived / legacy 的文档，以及和产品能力无关的贡献者指南类。

具体咋做查 ~/.vmap/skills/playbooks/，命令速查 ~/.vmap/skills/cheatsheet.md。

如果我要你调用 Codex CLI 直接推进实现或重构，先读：
- ~/.vmap/skills/playbooks/codex-goal-implement-loop.md
- ~/.vmap/skills/playbooks/codex-architecture-refactor-loop.md

每次 vmap 命令都会自动刷新 .vmap/vibe-map.html，我随时开来看图。开始吧。
```

---

## 给单文件分发的版本（不需要 install.sh，自己编译）

如果用户本地有 MoonBit：

```
请用 vibe-map 帮我维护这个项目的进度。

1. 克隆+构建：
   git clone https://github.com/eanzhao/vibe-map ~/.vmap-src
   cd ~/.vmap-src && moon install && moon build --target native --release
   mkdir -p ~/.local/bin && ln -sf ~/.vmap-src/_build/native/release/build/cmd/vmap/vmap.exe ~/.local/bin/vmap
   ln -sfn ~/.vmap-src/skills ~/.vmap/skills

2. 读规则：cat ~/.vmap/skills/SKILL.md

3. 在项目根：vmap init --name "我的项目"（加 .vmap/ 到 .gitignore）

接下来按 ~/.vmap/skills/playbooks/ 的指引推进。
```

---

## 调试技巧（给 agent）

如果某条 vmap 命令报错：

```bash
# 看 vmap 版本
vmap --version

# 看完整状态
vmap status --json | head -50

# 看某节点
vmap show <id>

# 复盘最近做的（gh CLI 已登录的话）
git diff HEAD~5 .vmap/vibe-map.json
```

退出码总览：
- `0` = 成功
- `1` = 业务错误（id 重复、循环、未知节点、release 校验失败等）→ 读 stderr 修
- `2` = CLI 参数错误 → 你拼错了，看 --help
- `3` = audit 违例 → 按 `~/.vmap/skills/playbooks/audit-fix-loop.md` 修
