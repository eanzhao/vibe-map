# Codex prompt — (re)generate rules.md from architecture docs

> Template. Required vars: `{{rules_path}}` `{{architecture_doc_paths}}` `{{prior_rules_path}}` `{{guard_scripts_dump}}`.
>
> 每轮 audit 前 controller 跑这个 prompt 一次，保证 rules.md 跟着 AGENTS.md / CLAUDE.md / docs/canon/ 的最新内容走，不让 stale rules.md 引导 audit 误判。

---

你是 vibe-map codex-architecture-refactor-loop 的**规则蒸馏 codex**。**只读，唯一可写文件 `{{rules_path}}`**。

## 输入

1. **架构文档**（按"更近 + 更具体"优先；不要漏掉目录内更近的 AGENTS）：

   {{architecture_doc_paths}}

2. **已有 CI guard / 测试 / linter 配置**（已被覆盖的规则只标 `enforced-by:`，不重复列）：

   ```
   {{guard_scripts_dump}}
   ```

3. **上一版 rules.md**（如果存在，用来 diff 出有没有规则被删 / 改 / 加；下面 "Changes" 节要列出）：

   `{{prior_rules_path}}`

## 任务

从架构文档原文蒸馏出可被 audit codex 程序化引用的规则集，覆盖率 ≥ 文档里"必须 / 禁止 / 应该"型条款的 90%。

## 输出格式（写到 `{{rules_path}}`）

```markdown
---
schema: vmap-codex-arch-rules-v1
generated_at: <ISO8601 UTC>
sources:
  - <doc-path-1>
  - <doc-path-2>
rule_count: <N>
---

# Architecture rules

## Changes since prior rules.md (optional, only if {{prior_rules_path}} existed)

- Added: arch-NNN (<reason / 文档新增条款>)
- Modified: arch-MMM (<旧措辞 → 新措辞>)
- Removed: arch-XXX (<文档不再约束 / 已被 guard 覆盖>)

## Rules

### RULE arch-001
- source: AGENTS.md#架构原则 段落 2
- level: must | should | never
- summary: <一句话规则；尽量是判定句>
- detect: <一句话告诉 audit codex 怎么找——"grep import X in dir Y" / "查找直接调用 Foo.* in src/api/"，要可机器执行>
- enforced-by: <如果有 CI guard 覆盖，写脚本 / 测试名；否则 "none">
- example_violation: |
    <一段从文档摘录的反例，或一段你能想到的代表性 code 片段>
- example_compliance: |
    <一段正例>

### RULE arch-002
- source: CLAUDE.md#字段命名
- level: must
- summary: ...
- detect: ...
- enforced-by: none
- example_violation: ...
- example_compliance: ...

...

## Notes / out-of-scope

<如果文档里有些约束太抽象、无法 detect（例如"代码要优雅"）写在这里说"不进 rules.md，audit 不抓"。透明>
```

## 字段语义

- `level: must` —— 任何违例都必须改（audit 抓 → 自动 cluster）
- `level: should` —— 默认遵守，但可在 cluster `Deviations` 节解释；audit 抓 + 提示
- `level: never` —— 禁止模式（任何引入 = blocking）
- `enforced-by: <guard>` —— 如果 CI 已守住，audit codex 仍可报但 controller 默认不开 cluster（已有 guard 兜底）；只有当 guard 漏掉时再补 cluster

## 硬约束

- **每条 RULE 必须能映射回文档原句**——`source:` 是文件 + 锚点，不是"听某人说"。
- **不要凭品味造规则**——文档没说"禁止 X" 你就不能加 `never X`。
- **不漏 already-enforced 规则**——即使 CI guard 已守住，audit 还是要知道有这条，写 `enforced-by:` 让 controller 跳。
- **不输出建议 / 评论 / 任务**——只蒸馏现有文档为规则。改文档要走维护模式（人 / 另一个 codex），不是这里。

## 完成 marker

末尾打印：

```
VMAP_CODEX_RULES_REGENERATED:<rule-count>:<changed|unchanged>
```

`<changed|unchanged>` 对比 `{{prior_rules_path}}` 判断；首次生成（无 prior）打印 `initial`。

开始蒸馏。
