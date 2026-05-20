# AGENTS.md

Conventions for AI agents working on vibe-map.

## Build & test

- `moon build` / `moon test` — needs the MoonBit toolchain.
- The renderer `src/render/html.mbt` emits a self-contained `vibe-map.html`.
  `examples/dag.html` is a committed sample — regenerate it whenever
  `html.mbt` changes so the example stays in sync.

## Releases — always publish to BOTH GitHub and mooncakes.io

Every release ships to two places. Never do one without the other:

1. **GitHub Releases** — cross-platform `vmap` binaries, for `install.sh` users.
2. **[mooncakes.io](https://mooncakes.io/docs/eanzhao/vibe-map)** — the MoonBit
   package registry.

### Release checklist (`vX.Y.Z`)

1. Bump `version` in `moon.mod.json` to `X.Y.Z`.
   Leave `src/core/version.mbt` as `"dev"` — the release CI bakes the tag in.
2. Add a row to the **Shipped** release table in `README.md` and `README_zh.md`.
3. Commit everything, push to `master`.
4. `git tag vX.Y.Z && git push origin vX.Y.Z`
   → `.github/workflows/release.yml` builds the binaries and publishes the
   **GitHub Release** automatically.
5. `moon publish` → publishes to **mooncakes.io**
   (needs the MoonBit toolchain + a one-time `moon login`).

A release is not done until step 5 has run. If the working machine has no
MoonBit toolchain, hand step 5 to the maintainer explicitly — do not silently
skip mooncakes.io.
