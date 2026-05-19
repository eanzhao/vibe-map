# vmap 分发设计（草案）

> 0.5.0 goal-vibe-map-bootstrap 的实现方案：让用户**复制一段 prompt 给 coding agent**，agent 自动装 vmap + skills，立刻能用。

## 目标

```
用户：把这段话发给 Claude / Codex / Cursor —— 然后 agent 就能在我的项目里用 vmap 推进工作了。
```

具体讲，agent 看到那段 prompt 要能：

1. **装上 vmap 二进制**（macOS / Linux 至少；Windows 后续）
2. **拿到 skills**（SKILL.md / cheatsheet.md / playbooks/*.md）
3. **知道接下来用 vmap 维护这个项目的 DAG**

零先决条件——用户不需要装 MoonBit、不需要 brew、不需要 npm。

---

## 推荐方案：GitHub Releases + install.sh

三段式：

### 第一段：`moon build --target native` 出二进制 → GitHub Releases

每次打 git tag (`v0.5.0` 这种) 触发 GitHub Actions，跨平台构建：

| Target | 文件名 |
|---|---|
| darwin-arm64 | `vmap-darwin-arm64.tar.gz` |
| darwin-x86_64 | `vmap-darwin-x86_64.tar.gz` |
| linux-x86_64 | `vmap-linux-x86_64.tar.gz` |
| linux-arm64 | `vmap-linux-arm64.tar.gz` |

每个 tarball 含 `vmap` 二进制 + `skills/` 目录 + LICENSE。

GitHub Actions workflow（草稿）：

```yaml
# .github/workflows/release.yml
name: release
on:
  push:
    tags: ['v*']
jobs:
  build:
    strategy:
      matrix:
        include:
          - { os: macos-14,      target: darwin-arm64 }
          - { os: macos-13,      target: darwin-x86_64 }
          - { os: ubuntu-22.04,  target: linux-x86_64 }
          - { os: ubuntu-22.04-arm, target: linux-arm64 }
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Install MoonBit
        run: curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
      - name: Build
        run: moon install && moon build --target native --release
      - name: Package
        run: |
          mkdir -p dist/vmap-${{ matrix.target }}
          cp _build/native/release/build/cmd/vmap/vmap.exe dist/vmap-${{ matrix.target }}/vmap
          cp -r skills dist/vmap-${{ matrix.target }}/
          cp LICENSE README.md dist/vmap-${{ matrix.target }}/ 2>/dev/null || true
          tar czf vmap-${{ matrix.target }}.tar.gz -C dist vmap-${{ matrix.target }}
      - uses: softprops/action-gh-release@v2
        with:
          files: vmap-${{ matrix.target }}.tar.gz
```

> 当前 README 没有 LICENSE，先用占位即可。

### 第二段：`install.sh` 一键脚本

放在 repo 根，URL 是稳定的：

```
https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh
```

脚本职责：
1. 检测 OS / arch（uname）
2. 找最新 release，下载对应 tarball
3. 解包，把 `vmap` 放到 `$HOME/.local/bin/`（如果不在 PATH 提示用户加）
4. 把 `skills/` 放到 `$HOME/.vmap/skills/`
5. 打印下一步：把哪段 prompt 给 agent

骨架（`install.sh`）：

```bash
#!/bin/bash
set -euo pipefail

REPO="eanzhao/vibe-map"
INSTALL_BIN="${HOME}/.local/bin"
INSTALL_SKILLS="${HOME}/.vmap/skills"

# 1. detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$OS-$ARCH" in
  darwin-arm64)  T=darwin-arm64 ;;
  darwin-x86_64) T=darwin-x86_64 ;;
  linux-x86_64)  T=linux-x86_64 ;;
  linux-aarch64) T=linux-arm64 ;;
  *) echo "unsupported: $OS-$ARCH" >&2; exit 1 ;;
esac

# 2. find latest release tag via GitHub API
TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | \
      grep -m1 '"tag_name"' | cut -d'"' -f4)
URL="https://github.com/${REPO}/releases/download/${TAG}/vmap-${T}.tar.gz"

# 3. download + extract
TMP=$(mktemp -d)
curl -fsSL "$URL" | tar xz -C "$TMP"
mkdir -p "$INSTALL_BIN" "$INSTALL_SKILLS"
mv "$TMP/vmap-${T}/vmap" "$INSTALL_BIN/vmap"
chmod +x "$INSTALL_BIN/vmap"
rm -rf "$INSTALL_SKILLS"
mv "$TMP/vmap-${T}/skills" "$INSTALL_SKILLS"
rm -rf "$TMP"

# 4. PATH hint
echo "installed: $INSTALL_BIN/vmap (version $TAG)"
echo "skills:    $INSTALL_SKILLS/"
case ":$PATH:" in
  *":$INSTALL_BIN:"*) ;;
  *) echo "  ⚠️  $INSTALL_BIN not in PATH. Add to your shell rc:"
     echo "      export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
echo
echo "next: tell your coding agent to read $INSTALL_SKILLS/SKILL.md"
```

### 第三段：bootstrap prompt（用户复制这段给 agent）

```
请在当前项目里用 vibe-map 帮我推进工作。

1. 装 vmap CLI（如果还没装）：
   curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/master/install.sh | bash

2. 读这份指南，理解 vmap 的工作模式：
   cat ~/.vmap/skills/SKILL.md
   ls ~/.vmap/skills/playbooks/

3. 在当前项目根目录初始化（如果还没初始化）：
   vmap init --name "<我的项目名>"
   # 把 .vmap/ 加到 .gitignore

4. 从这里开始，每个进展都用 vmap CLI 记下来：
   - 接到新需求 → vmap add goal（按语义/PRD 视角，不是按 package）
   - 拆实现路径 → vmap add task
   - 每完成一步 → vmap update --status done
   - 阶段推进 → vmap update --closure scoped/public/...
   - 关键节点 → vmap audit

每次 mutating 命令后 .vmap/vibe-map.html 会自动刷新，我会随时打开看。

具体怎么做按 ~/.vmap/skills/playbooks/ 下的 playbook 来：
- new-feature.md   接到新需求怎么放进图
- audit-fix-loop.md  audit 报红怎么修
- release-shipping.md 怎么收 release
- daily-progress.md  我问"做到哪了"时怎么回我

如有不确定的命令查 ~/.vmap/skills/cheatsheet.md。
```

---

## 为什么不选其它方案

| 方案 | 否定理由 |
|---|---|
| `brew install` | macOS 限定，需要单独维护 tap 仓 |
| `npm install -g` | 跟 Node 生态绑定怪异；中国大陆 npm 镜像也是个变量 |
| `cargo install` / `pip install` | 需要装目标语言工具链，悖背"零先决条件" |
| `moon install` | MoonBit registry 当前不支持安装可执行工具 |
| `git clone + moon build` | 用户得装 MoonBit；编译时间分钟级；不适合 quickstart |

GitHub Releases + install.sh 是**最少依赖、最普世、agent 最容易跑通**的路径。

## 风险 / 待办

1. **MoonBit 跨平台 build**：当前 `moon build --target native` 在 macOS arm64 上能跑。Linux x86_64 应该 ok（CI runner 标配）。**arm64 Linux 和 macOS x86_64 没验过**——发版前要在 GitHub Actions 上 dry-run。
2. **静态链接**：MoonBit 的 native binary 是不是 statically linked？libc 依赖会影响 Linux 分发。要 verify。如果不是，用 musl-based runner 或加 docker 构建。
3. **release notes 自动化**：可以用 `vmap release list --json` 输出当前 release 的 goals 喂给 GitHub Release 描述。这是 `goal-llm-plan` 的对偶——release notes 也可以从 vmap 抽。
4. **HTTPS 信任**：`curl | bash` 是争议做法。给用户两条路：
   - 一键：`curl ... | bash`
   - 慎重：`curl ... > install.sh; less install.sh; bash install.sh`
5. **二进制签名**：macOS 可能跳 Gatekeeper 警告。考虑 codesign + notarize（后期）。
6. **国内网络**：raw.githubusercontent.com / github.com release 在大陆经常被墙。准备一个镜像（比如 jsdelivr / 腾讯云对象存储）作为 fallback：
   ```bash
   curl -fsSL https://cdn.jsdelivr.net/gh/eanzhao/vibe-map@main/install.sh | bash
   ```
7. **Windows**：第一阶段不支持；用户在 Windows 上跑 WSL。

## 实施顺序（落到 0.5.0）

| Task | 工作量 | 文件 |
|---|---|---|
| `install.sh` 脚本 + 本地 dry-run | ~半天 | `install.sh` |
| `.github/workflows/release.yml` GH Actions 构建 + 上传 release artifacts | ~1 天 | `.github/workflows/release.yml` |
| 准备 LICENSE（用 MIT / Apache-2.0 / 等） | 10 分钟 | `LICENSE` |
| 第一个 tagged release (v0.5.0-alpha.1) + 验证 install.sh | 半天 | git tag |
| README 顶部加 "install one-liner" 段 | 10 分钟 | `README.md` |
| Bootstrap prompt 落到 `skills/vibe-map-bootstrap.md` | 10 分钟 | `skills/vibe-map-bootstrap.md` |

## Alternative: 当前能立刻做的（不用等 CI）

如果想**今晚就能让 ta 试** bootstrap prompt：

1. 本地 `moon build --target native --release`
2. 把 `_build/native/release/build/cmd/vmap/vmap.exe` 上传到某处（GitHub Releases、Cloudflare R2、个人 nas）
3. `install.sh` 写死下载链接，先支持 darwin-arm64 一种
4. 跑通后再补 CI 自动化

这是**先验证 prompt 工作流可行**的最小路径，跑通再正式化 CI。
