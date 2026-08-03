# zstack

**面向独立开发者的 Agent Skill 集合** —— 让 AI 编程助手不只会写代码，还会帮你**验证需求、访谈用户、烟雾测试、写 PRD、做 SEO**。

**语言：** [English](./README.md) · 中文（本文件）

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Validate](https://github.com/zh30/zstack/actions/workflows/validate.yml/badge.svg)](https://github.com/zh30/zstack/actions/workflows/validate.yml)
[![Skills](https://img.shields.io/badge/skills-5-brightgreen)](./skills/)
[![Hosts](https://img.shields.io/badge/hosts-Claude%20%7C%20Codex%20%7C%20Grok-black)](./ARCHITECTURE.md#3-how-each-host-discovers-skills)

---

## 问题从哪来（第一性原理）

独立开发者第一次拥有了上一代人没有的东西：**能快速写出大量软件的 AI Agent**。

于是出现了一种新的失败方式。

| AI 已经很容易的事 | 仍然很难、却决定生死的事 |
|-------------------|--------------------------|
| 搭脚手架、堆功能 | 判断**有没有人需要** |
| 改 UI、写测试 | **真人对话**且不被恭维骗到 |
| 无限重构 | 在写几个月代码前**测真实需求** |
| 生成文案与文档 | 写出**可落地**的产品定义 |
| 批量产出内容 | 用诚实的搜索策略**赚到注意力** |

**第一性原理：** 代码是对「决策」的杠杆。决策错了，代码越多，浪费越大。

大多数 Agent 工具优化左栏。**zstack 优化右栏** —— 一人公司最不能省掉的**产品判断闭环**。

---

## 什么是 Agent Skill？

你不需要懂 AI 底层也能用。

可以把 **Skill** 理解成：**Agent 按需加载的作业手册**：

1. 你用宿主语法选择 `z-market-validate`（Claude/Grok 用 `/`，Codex 用
   `$`），或直接用自然语言说出意图。
2. Agent 打开一份 `SKILL.md` —— 里面是步骤、清单、质量标准。
3. 它用平时的能力（搜索、改文件、跑命令）按手册执行。
4. 你得到的是**可重复的流程**，不是聊完就散的一次性对话。

**给专业读者：** Skill 遵循常见的 Agent Skills 约定（YAML frontmatter 的 `name` / `description` + Markdown 正文）。一份源文件通过 symlink 安装到 Claude Code、Codex、Grok 兼容目录。发现路径、frontmatter 策略与安装模型见 [ARCHITECTURE.md](./ARCHITECTURE.md)。

---

## zstack 是什么

zstack 是一套**开源、原创**的 Skill 集合，服务**一人公司 / 独立开发者 / indie hacker**。

它是：

- 一条**产品工作流**（验证 → 发现 → 烟雾测试 → 规格 → SEO）
- **跨主流 AI 编程 Agent** 可移植
- **一条命令安装**
- **用 Git 版本管理**，手册会随项目进化

它**不是**：

- [gstack](https://github.com/garrytan/gstack) 一类工程工厂的替代品（`/qa`、`/ship`、`/browse` 等请继续用 gstack；zstack 专注**产品真相**）
- 把别人的 skill 打包搬运的仓库
- 必须额外部署的独立 Agent 服务或 SaaS

---

## 适合谁

| 你会觉得对味，如果… | 你可能需要别的东西，如果… |
|---------------------|---------------------------|
| 几乎一个人做产品 | 要完整的大企业产品运维套件 |
| 使用 Claude Code / Codex / Grok Build | 只要提示词、不要安装与规范 |
| 曾做出「AI 写完却没人要」的应用 | 只要代码审查 / 浏览器 QA（看 gstack） |
| 希望流程能跨项目复利 | 想要黑箱「AI CEO」、不看步骤 |

---

## 产品旅程

Skill 可以串联使用。默认路径：

```text
  半成品想法
       │
       ▼
  z-market-validate      ← 公开信号：有没有人在喊疼 / 付钱？
       │
       ▼
  z-customer-discovery   ← 真人访谈（Mom Test）：过去行为，不是客套
       │
       ▼
  z-landing-smoke        ← 最低成本行为测试：落地页 + 等待列表 / 预售
       │
       ▼
  z-write-prd            ← 这时才写可构建的产品定义
       │
       ▼
  写代码（你的技术栈 + 工程类 skill）
       │
       ▼
  z-seo-plan             ← 有值得被搜到的东西之后再做搜索
```

**为什么是这个顺序？**

1. **公开信号**便宜，能杀掉明显伪需求。  
2. **访谈**提供爬不到的真相，并对抗自我欺骗。  
3. **烟雾测试**要的是**行为**（留资、付钱），不是口头好评。  
4. 没有以上步骤的 **PRD**，常常是高自信地描写虚构。  
5. 在错误产品上做 **SEO**，等于给死胡同买广告。

---

## Skills 一览

所有 skill 以 **`z-` 前缀**命名，避免和机器上其他 skill 包撞名。

| Skill | Skill id | 一句话（外行） | 更深层目标 |
|-------|------|----------------|------------|
| [z-market-validate](./skills/z-market-validate/) | `z-market-validate` | 「这想法值不值得花一周？」 | 多渠道需求扫描（X、Reddit、HN、PH…），正反证据，独立开发者适配度，30–90 天回报，切入 wedge |
| [z-customer-discovery](./skills/z-customer-discovery/) | `z-customer-discovery` | 「找 5–15 个真人聊，且别被恭维骗了」 | Mom Test 教练：招募、提纲、复盘、合成痛点 / 已有支出 / 切换意愿 |
| [z-landing-smoke](./skills/z-landing-smoke/) | `z-landing-smoke` | 「最便宜地看有没有人在乎」 | 英文落地页 + 等待列表/预售、引流计划、转化与止损线 |
| [z-write-prd](./skills/z-write-prd/) | `z-write-prd` | 「把笔记变成能开工的规格」 | 一人公司体量 PRD：问题、范围、需求 ID、验收标准、非目标、里程碑 |
| [z-seo-plan](./skills/z-seo-plan/) | `z-seo-plan` | 「到底该抢哪些搜索词？」 | 从 PRD/URL/代码做关键词研究、主词、页面地图、on-page/技术注意 — 禁止伪造搜索量 |

每个 skill 带有 `references/`（模板、质检清单、手册）。完整方法论在那里；Agent 执行时会按指示去读。

---

## 快速开始

### 环境要求

- macOS 或 Linux。Windows 请使用 WSL；原生 Windows 目前尚未测试。
- [Git](https://git-scm.com/)
- 至少一种：[Claude Code](https://code.claude.com/docs/en/skills)、[OpenAI Codex](https://developers.openai.com/codex/skills)、[Grok Build](https://x.ai)
- `bash`（安装与检查脚本）
- 贡献测试、严格 YAML/证据校验及路由评测工具需要 Ruby 2.6+；基础安装与卸载仍
  只依赖 Bash

### 安装

```bash
git clone https://github.com/zh30/zstack.git ~/code/zstack
cd ~/code/zstack
./scripts/setup.sh
./scripts/doctor.sh
```

`doctor.sh` 默认会报告发现的全部问题。专注迭代时可用 `--source-only`
跳过已安装链接检查，或用 `--fail-fast` 在首个错误处停止。

`setup.sh` 默认只把 active skill 链接到当前必要的发现目录；旧版或专用
兼容目录可通过 `--hosts` 显式启用：

| Profile | 目录 | 默认 | 原因 |
|---------|------|------|------|
| Agent Skills 中枢 | `~/.agents/skills/` | 是 | 当前 Codex 用户目录；Grok 也会发现 |
| Claude Code | `~/.claude/skills/` | 是 | Claude 用户目录；Grok 兼容扫描 |
| 旧版 Codex | `~/.codex/skills/` | 否 | 旧版兼容：`./scripts/setup.sh --hosts codex` |
| Grok 专用目录 | `~/.grok/skills/` | 否 | 显式可选：`./scripts/setup.sh --hosts grok` |

显式 `--hosts` 会启用 optional profile；以后不带参数的默认运行不会改动
该未选目录。

在 `skills/` 里改文件，所有宿主立刻看到更新（symlink）。
遇到冲突时，setup 会跳过并返回非零状态；传入 `--force` 才会先原子预留
带时间戳且不会碰撞的备份目录，并把旧路径保存到
`*.zstack-backup-*/original`。若随后创建链接失败，setup 会自动恢复原路径。
全局链接与 `--project` 链接都会被记录，可安全清理：

```bash
./scripts/unlink.sh
```

卸载不会删除冲突备份或任何非符号链接内容。
重复运行 setup 时，只会对账所选宿主目录：已变为 draft/deprecated、或不再
允许该宿主的链接会被移除；未选择的宿主和其他 zstack clone 不受影响。

### 使用

显式调用语法因宿主而异：

```text
Claude / Grok: /z-market-validate
Codex:         $z-market-validate
```

自然语言在各宿主间可移植：

```text
做客户发现 setup。ICP：独立设计顾问。痛点：每周客户报告。目标 10 场访谈。
```

---

## 原理（给想看门道的人）

```text
┌──────────────────────────┐
│  本 Git 仓库              │
│  skills/z-*/SKILL.md     │  ← 唯一真相源
└────────────┬─────────────┘
             │  ./scripts/setup.sh  （符号链接）
         ┌───────┴────────┐
         ▼                ▼
 ~/.agents/skills  ~/.claude/skills
   Codex + Grok       Claude + Grok

 显式可选兼容目录：~/.codex/skills、~/.grok/skills
```

**设计取舍（第一性原理）：**

| 取舍 | 原因 |
|------|------|
| Markdown 手册，而不是新运行时 | Agent 已会执行；我们约束的是**判断** |
| Symlink 安装 | 改一处、处处生效，无过期副本 |
| `z-` 前缀 | 共享 skill 目录拥挤，命名空间防撞车 |
| 只放原创 skill | 开源许可与质量口径一致 |
| 默认只装当前目录 | Codex 使用 `~/.agents`，Claude 使用 `~/.claude`，Grok 会发现两者 |
| 旧版目录显式启用 | 避免写入无效重复目录，同时保留旧版 Codex 与 Grok 专用目录兼容性 |
| 证据优于感觉 | 强制反面检索、Mom Test、止损线 |

更深： **[ARCHITECTURE.md](./ARCHITECTURE.md)** · 写作规范： **[docs/authoring.md](./docs/authoring.md)** · 仓库内 AI 协作规则： **[AGENTS.md](./AGENTS.md)**。

---

## 仓库结构

```text
zstack/
├── README.md                 # 英文主文档
├── README.zh-CN.md           # 中文（本文件）
├── ARCHITECTURE.md           # 多宿主架构
├── AGENTS.md                 # 改本仓库时的 Agent 规则
├── CONTRIBUTING.md           # 贡献流程与质量门禁
├── catalog.yaml              # Skill 注册表
├── hosts/                    # 各 Agent 安装配置
├── evals/
│   ├── cases.yaml            # 行为回归提示与判定标准
│   ├── routing.yaml          # 仅基于 description 的技能路由案例
│   └── runs/                 # 按日期保存的干净上下文响应与评分
├── scripts/
│   ├── setup.sh              # 安装 / 刷新链接
│   ├── doctor.sh             # 校验 skill 与链接
│   ├── test.sh               # 安装器与校验器集成测试
│   ├── new-skill.sh          # 脚手架 z-* skill
│   ├── unlink.sh             # 仅移除 zstack 管理的链接
│   ├── check-evidence-docs.rb # 保持文档宿主覆盖与证据报告一致
│   ├── report-evidence-coverage.rb # 行为 / 路由 provenance 覆盖矩阵
│   ├── run-behavioral-evals.rb # 共享的隔离行为 runner 核心
│   ├── run-{codex,claude,grok}-behavioral-evals.rb # 宿主入口
│   ├── archive-behavioral-run.rb # 共享的已复核归档核心
│   ├── archive-{codex,claude,grok}-behavioral-run.rb # 宿主入口
│   ├── run-routing-evals.rb # 共享的隔离 description 路由核心
│   ├── run-{codex,claude,grok}-routing-evals.rb # 各宿主入口
│   ├── archive-routing-run.rb # 共享的路由原子归档核心
│   ├── archive-{codex,claude,grok}-routing-run.rb # 各宿主归档入口
│   ├── generate-evidence-manifests.rb # 重建 / 检查完整评测档案摘要
│   ├── validate-yaml.rb      # 可选严格 YAML / 重复键校验
│   ├── validate-evidence.rb  # 评测档案 JSON / 字节数 / SHA-256 校验
│   └── lib/                  # 共享解析与稳定的评测 / 证据输入契约
├── skills/
│   ├── _template/
│   ├── z-market-validate/
│   ├── z-customer-discovery/
│   ├── z-landing-smoke/
│   ├── z-write-prd/
│   └── z-seo-plan/
└── docs/
    ├── authoring.md
    ├── compatibility.md
    ├── evidence-handoff.md
    ├── evaluation.md
    └── frontmatter.md
```

---

## 新增或扩展 Skill

```bash
./scripts/new-skill.sh z-my-workflow product
# 编辑 SKILL.md，并定制自动生成的 references/quality-bar.md
# 检查 catalog.yaml 中自动创建的 draft 条目
# 添加三个行为案例（含 happy-path）+ 两个路由案例，再改为 active
./scripts/test.sh
./scripts/setup.sh
```

要点：

1. **name** = 目录名 = 可移植 skill id；必须符合 `z-[a-z0-9-]+`。
2. **`description`** 是自动触发的接口 —— 写清触发词。
3. 正文对**任意宿主**可执行：少写宿主专有工具名，多写「跑命令 / 读文件」。
4. 长材料放 `references/`；`SKILL.md` 保持可执行。
5. 无密钥、无本机绝对路径。
6. 新脚手架已包含 Evidence handoff 与质量门槛基线，但会故意保持验证失败，
   直到正文与 catalog 占位符都被替换；draft 状态暂不要求行为或路由案例。

欢迎提交 PR；原创内容规则、必跑检查与 smoke-test 证据要求见
[CONTRIBUTING.md](./CONTRIBUTING.md)。
行为与路由测试方法见 [docs/evaluation.md](./docs/evaluation.md)。
归档运行会把模型原始响应与评分分开保存；当前运行矩阵见
[宿主兼容性证据](./docs/compatibility.md)。通过的归档只代表该日期、该运行器下的
证据，不保证所有模型和宿主都会得到相同结果。最新 Codex 路由证据包括
[上下文预算回归](./evals/runs/2026-08-01-codex-routing-budget/summary.md) 与
[中文路由回归](./evals/runs/2026-08-01-codex-routing-zh/summary.md)，两者都保留了
原始选择结果。
同一路由协议现已拥有经复核的
[Grok 25 案例矩阵](./evals/runs/2026-08-01-grok-routing-full-matrix/summary.md)，
以完整 provenance 覆盖全部英文、中文、边界和 no-match 请求。
五个 skill 的完整产出 [happy-path 测试](./evals/runs/2026-07-31-happy-path/summary.md)
也已全部通过，并保留了原始工件。
经逐条复核的 Codex 韧性矩阵 [A](./evals/runs/2026-08-01-codex-behavioral-resilience-matrix-a/summary.md)
与 [B](./evals/runs/2026-08-01-codex-behavioral-resilience-matrix-b/summary.md)
在 2026-08-01 的源码快照上首次把完整 provenance 覆盖提升到 20/20。
随后的 [宿主缺口审计](./evals/runs/2026-08-01-codex-happy-gap-regression/summary.md)
保留了 3 个通过与 1 个真实工件失败；隔离的
[artifact 重跑](./evals/runs/2026-08-01-codex-landing-artifact-pass/summary.md)
保留了可部署页面，并在该快照上把 Codex 宿主自身的完整覆盖补到 20/20。
同一套源码快照、防泄漏、人工复核与原子归档协议现已提供 Claude Code
适配器；它分别记录请求模型与实际模型，并在宿主把 API 错误包装成名义上的
success 结果时仍会拒绝归档。在 2026-08-02 的本机复核中，Claude 提供方在
生成前返回模型不可用；运行器将其脱敏标记为 `model-unavailable`，没有把外部
配置错误算成 skill 通过。
Grok 适配器进一步加入带有界稳定 auth 副本的隔离宿主目录、匿名描述符 prompt-file 传输、精确 final-response
边界、工具与 sandbox 控制、脱敏 API 错误分类，以及同样的私有 provenance
核验。经复核的
[19 案例 response 矩阵](./evals/runs/2026-08-01-grok-behavior-current-full-response/summary.md)
是早期 skill 快照的历史证据；已保留的
[landing artifact 失败](./evals/runs/2026-08-01-grok-behavior-current-smoke-artifact-unverified-success/summary.md)
推动了更严格的 provider-confirmed-success 规则。后续 progressive-disclosure
编辑改变了五个 skill 正文，因此 20 个行为案例都需要新的 Grok 运行；
2026-08-02 的 Grok CLI 0.2.118 在生成前返回 HTTP 401。确定性的假宿主测试
不计入模型证据。随后保留的
[provider schema 失败](./evals/runs/2026-08-01-codex-landing-artifact-provider-schema-failure/summary.md)
又识别出猜测 Buttondown tag ID 的问题。skill 现在要求带日期的官方 provider
语义，或显式、阻止上线的 `VERIFY_*` 映射。Codex 在 2026-08-02 重新复核了
[市场验证](./evals/runs/2026-08-02-codex-market-progressive-disclosure/summary.md)、
[PRD](./evals/runs/2026-08-02-codex-prd-progressive-disclosure/summary.md)、
[SEO](./evals/runs/2026-08-02-codex-seo-progressive-disclosure/summary.md)、
[客户发现](./evals/runs/2026-08-02-codex-discovery-progressive-disclosure/summary.md)，
以及 landing 的 [response](./evals/runs/2026-08-02-codex-landing-progressive-disclosure-response/summary.md)
与 [artifact](./evals/runs/2026-08-02-codex-landing-progressive-disclosure-artifact/summary.md)，
在对应源码快照上通过全部 20 个案例。最新 artifact 会把未知归因排除在决策 lane 外，
在 analytics 初始化前清除 query 与 fragment，在显式 contract 占位符尚未解决时
不请求 analytics 或 Buttondown，并且不暴露 provider 或异常原始数据。Function
通过了 18 个本地恶意 intake/provider 场景，包括不信任 `Content-Length` 的真实
流字节上限；确定性的浏览器检查也证明了关闭的 analytics gate 与有界归因。
CI 会同时要求行为与路由证据匹配当前 skill 字节，因此 Grok 缺口会失败关闭，
直到认证恢复并发布经复核的新归档。

<!-- zstack-current-evidence:start -->
当前源码证据：Claude 行为 **0/20**，
Codex 行为 **20/20**，Grok 行为
**0/20**；Claude 路由 **0/25**，
Codex 路由 **25/25**，Grok 路由 **25/25**。
<!-- zstack-current-evidence:end -->

跨宿主发现证据及五个 Grok happy-path 的完整结果，记录在
[宿主兼容性证据](./docs/compatibility.md) 中；其中保留了推动 discovery、
landing 完整性与 PRD 修复的失败证据。

---

## 常见问题

**必须装齐三个 Agent 吗？**  
不必。本机有哪些 skill 根目录，就装哪些。

**这会替我写完整个产品吗？**  
Skill 产出的是**决策与工件**（报告、访谈提纲、落地页文案、PRD、SEO 方案）。判断、约人、上线仍是你的。

**为什么 `z-landing-smoke` 默认英文落地页？**  
默认面向全球烟雾测试；ICP 以中文市场为主时可改为中文页。实验记录语言跟随你。

**和 gstack 是什么关系？**  
无隶属。互补。不要占用 gstack 短名（`qa`、`ship` 等）。

**能把别人的 skill 搬进仓库吗？**  
项目策略：**只收原创 skill**。需要时在文档外链即可。

---

## 状态

持续开发中：`github.com/zh30/zstack`。

| 模块 | 状态 |
|------|------|
| Skill 目录（5 个） | 可用 |
| 多宿主 setup/doctor | 可用 |
| 架构文档 | 可用 |
| CI 校验 | 已配置；宿主证据缺口会失败关闭（见上方当前源码证据块） |
| 贡献指南 | 可用 |

---

## 许可

[MIT](./LICENSE) —— 可自由使用、修改与分发，保留署名即可。

---

## 维护者

为一人公司而写：拒绝把**写出代码**误当成**交付价值**。

若这套 skill 帮你避开了一条死胡同，欢迎 star，并在 issue 里写下你学到了什么 —— 那是手册变锋利的唯一方式。
