# zstack

**面向独立开发者的 Agent Skill 集合** —— 让 AI 编程助手不只会写代码，还会帮你**验证需求、访谈用户、烟雾测试、写 PRD、做 SEO**。

**语言：** [English](./README.md) · 中文（本文件）

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Skills](https://img.shields.io/badge/skills-5-brightgreen)](./skills/)
[![Hosts](https://img.shields.io/badge/hosts-Claude%20%7C%20Codex%20%7C%20Grok-black)](#兼容哪些-agent)

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

1. 你输入 `/z-market-validate`，或用自然语言说出意图。  
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

| Skill | 命令 | 一句话（外行） | 更深层目标 |
|-------|------|----------------|------------|
| [z-market-validate](./skills/z-market-validate/) | `/z-market-validate` | 「这想法值不值得花一周？」 | 多渠道需求扫描（X、Reddit、HN、PH…），正反证据，独立开发者适配度，30–90 天回报，切入 wedge |
| [z-customer-discovery](./skills/z-customer-discovery/) | `/z-customer-discovery` | 「找 5–15 个真人聊，且别被恭维骗了」 | Mom Test 教练：招募、提纲、复盘、合成痛点 / 已有支出 / 切换意愿 |
| [z-landing-smoke](./skills/z-landing-smoke/) | `/z-landing-smoke` | 「最便宜地看有没有人在乎」 | 英文落地页 + 等待列表/预售、引流计划、转化与止损线 |
| [z-write-prd](./skills/z-write-prd/) | `/z-write-prd` | 「把笔记变成能开工的规格」 | 一人公司体量 PRD：问题、范围、需求 ID、验收标准、非目标、里程碑 |
| [z-seo-plan](./skills/z-seo-plan/) | `/z-seo-plan` | 「到底该抢哪些搜索词？」 | 从 PRD/URL/代码做关键词研究、主词、页面地图、on-page/技术注意 — 禁止伪造搜索量 |

每个 skill 带有 `references/`（模板、质检清单、手册）。完整方法论在那里；Agent 执行时会按指示去读。

---

## 快速开始

### 环境要求

- macOS 或 Linux（默认 symlink 安装；Windows 需开发者模式或 pull 后重跑 setup）
- [Git](https://git-scm.com/)
- 至少一种：[Claude Code](https://docs.anthropic.com/en/docs/claude-code)、[OpenAI Codex CLI](https://github.com/openai/codex)、[Grok Build](https://x.ai)
- `bash`（安装与检查脚本）

### 安装

```bash
git clone https://github.com/<your-org>/zstack.git ~/code/zstack
cd ~/code/zstack
./scripts/setup.sh
./scripts/doctor.sh
```

`setup.sh` 会把各个 skill 链接到：

| 宿主 | 默认目录 |
|------|----------|
| Agent Skills 中枢 | `~/.agents/skills/` |
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Grok Build | 默认依赖对 agents/claude 的兼容扫描（`hosts/grok` 关闭） |

在 `skills/` 里改文件，所有宿主立刻看到更新（symlink）。

### 使用

在 Agent 会话中：

```text
/z-market-validate
我想做一个把会议纪要自动变成客户发票的工具，面向自由职业者。
```

或自然语言：

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
     ┌───────┼────────┐
     ▼       ▼        ▼
 ~/.agents  ~/.claude ~/.codex
     │       │
     └───────┴──► Grok 也会扫描这些目录
```

**设计取舍（第一性原理）：**

| 取舍 | 原因 |
|------|------|
| Markdown 手册，而不是新运行时 | Agent 已会执行；我们约束的是**判断** |
| Symlink 安装 | 改一处、处处生效，无过期副本 |
| `z-` 前缀 | 共享 skill 目录拥挤，命名空间防撞车 |
| 只放原创 skill | 开源许可与质量口径一致 |
| 默认不单独装 Grok 目录 | Grok 已读 `~/.agents` / `~/.claude` |
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
├── catalog.yaml              # Skill 注册表
├── hosts/                    # 各 Agent 安装配置
├── scripts/
│   ├── setup.sh              # 安装 / 刷新链接
│   ├── doctor.sh             # 校验 skill 与链接
│   ├── new-skill.sh          # 脚手架 z-* skill
│   └── unlink.sh             # 仅移除 zstack 管理的链接
├── skills/
│   ├── _template/
│   ├── z-market-validate/
│   ├── z-customer-discovery/
│   ├── z-landing-smoke/
│   ├── z-write-prd/
│   └── z-seo-plan/
└── docs/
    ├── authoring.md
    └── frontmatter.md
```

---

## 新增或扩展 Skill

```bash
./scripts/new-skill.sh z-my-workflow
# 编辑 skills/z-my-workflow/SKILL.md
# 在 catalog.yaml 注册
./scripts/doctor.sh
./scripts/setup.sh
```

要点：

1. **name** = 目录名 = 斜杠命令；必须符合 `z-[a-z0-9-]+`。  
2. **`description`** 是自动触发的接口 —— 写清触发词。  
3. 正文对**任意宿主**可执行：少写宿主专有工具名，多写「跑命令 / 读文件」。  
4. 长材料放 `references/`；`SKILL.md` 保持可执行。  
5. 无密钥、无本机绝对路径。

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

持续开发中。公开远程地址在发布前请自行替换 Quick start 中的 clone URL。

| 模块 | 状态 |
|------|------|
| Skill 目录（5 个） | 可用 |
| 多宿主 setup/doctor | 可用 |
| 架构文档 | 可用 |
| CI / CONTRIBUTING | 计划中 |

---

## 许可

[MIT](./LICENSE) —— 可自由使用、修改与分发，保留署名即可。

---

## 维护者

为一人公司而写：拒绝把**写出代码**误当成**交付价值**。

若这套 skill 帮你避开了一条死胡同，欢迎 star，并在 issue 里写下你学到了什么 —— 那是手册变锋利的唯一方式。
