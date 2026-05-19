# Playbook — 收一个 release

> 一个 release 的 goal 都做完了，怎么把它落版。

## 何时该收 release

用户说"准备发版"，或者你判断：

```bash
vmap release list --json
# 看 0.4.0 的成员 goal 都 closure=public 或以上了吗？
```

或者更精确：

```bash
# Stage 2 之后会有 vmap release status 命令直接看是否 ready_to_close
vmap status --release 0.4.0
# 看每个 goal 是不是 closure ≥ public
```

## 步骤

### 1. 检查是否 ready

每个属于这个 release 的 goal，closure 都要 ≥ `public`：

```bash
vmap list goals --release 0.4.0
# 输出每个 goal 的 closure。任何 closure=seed/obligation/scoped 都是 blocker。
```

如果有 blocker：

```bash
# 选 A: 继续推这个 goal
vmap update goal-xxx --closure public

# 选 B: 把它从这个 release 移出（推迟到下一版）
vmap release unassign 0.4.0 --goals goal-xxx
vmap update goal-xxx --milestone 0.5.0
# 或先移出，等下再决定归哪个 release
```

### 2. audit 一遍

```bash
vmap audit --json
# exit 0 才能继续
```

GitHub issue 数也校一下：

```bash
python3 tools/audit_github.py --file .vmap/vibe-map.json --strict
```

### 3. 改 release 状态

```bash
vmap release update 0.4.0 --status closed
```

> ⚠️ `closed → open` 不可逆。确认全部就绪再做。
>
> Stage 2 之后会有 `vmap release close 0.4.0` 一键命令，含 ready 校验 + 状态推进 + 可选 CHANGELOG 草稿生成。当前手动两步。

### 4. CHANGELOG / git tag（vmap 之外）

vmap 不管 git 操作。这一步是常规：

```bash
git tag -a v0.4.0 -m "release 0.4.0: release modeling + audit + viz polish"
git push origin v0.4.0
```

如果项目有 CHANGELOG.md，把这一版的 goal 标题摘抄进去：

```bash
vmap list goals --release 0.4.0 --json | python3 -c "
import json, sys
goals = json.load(sys.stdin)
print('## 0.4.0')
print()
for g in goals:
    print(f'- {g[\"title\"]}')
" >> CHANGELOG.md
```

### 5. 把当前焦点切到下一版

```bash
vmap list goals --release 0.4.0 --focus
# 这些 goal 的 focus 撤掉
for gid in $(vmap list goals --release 0.4.0 --focus --json | python3 -c "import json,sys; [print(g['id']) for g in json.load(sys.stdin)]"); do
  vmap update $gid --no-focus
done

# 下一版的 focus 打开
vmap update goal-xxx --focus
```

### 6. archive 老 release 的 mature goal（可选）

如果有 goal 已经 `mature` 超过 30 天，可以 archive 掉，让画布更干净：

```bash
vmap update goal-old --archived
```

archived goal 在 viz 里淡入背景，但所有数据保留。

## 一个完整 release-shipping 示例

```bash
# 1. 当前在 0.4.0 收尾
vmap status --release 0.4.0

# 2. 一个 goal 还是 scoped，决定推迟
vmap release unassign 0.4.0 --goals goal-llm-plan
vmap update goal-llm-plan --milestone 1.0.0

# 3. 剩下都 public+，audit 一遍
vmap audit                            # exit 0
python3 tools/audit_github.py --file .vmap/vibe-map.json --strict

# 4. 关
vmap release update 0.4.0 --status closed

# 5. 撤焦点
vmap update goal-release-modeling --no-focus
vmap update goal-audit --no-focus
vmap update goal-viz --no-focus

# 6. 切到 0.5.0
vmap update goal-vibe-map-bootstrap --focus
vmap update goal-auto-render --focus
vmap update goal-vmap-dir --focus

vmap release update 0.5.0 --status open
```

## 别犯的错

1. ❌ **`closed` 之后又改主意** —— `closed → open` 不可逆。改主意要新建 `0.4.1` 补丁版。
2. ❌ **没 audit 直接 close** —— close 之后任何 missing_tests / missing_docs 都是技术债。
3. ❌ **把还没 public 的 goal 留在 0.4.0** —— close 后 audit 会报 `release_blocked`（Stage 2）。
4. ❌ **忘了切焦点** —— 用户打开 viz 还看到一堆已经发版的红框 focus，不知道下一步在做什么。
