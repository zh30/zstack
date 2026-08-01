# Chinese routing prompts

Each clean session received the five descriptions in
`raw/candidate-descriptions.txt`, rotated left by `case_index % 5` from
alphabetical skill order, and one registered request below. Expected selections,
grading notes, skill bodies, repository files, and other responses were hidden.

The exact shared wrapper was:

> 只根据下面候选 skill 的 frontmatter 描述，为一个用户请求选择路由。不要使用工具、
> 读取文件或加载已安装的 skill 正文。
>
> 候选 skills：
> [五个候选描述，按本 case 的顺序]
>
> 用户请求：
> [下面的一个请求]
>
> 严格只回复两行：
> selection: &lt;一个候选 id 或 none&gt;
> reason: &lt;一句简短中文理由&gt;

## zh-market-public

我有个给独立咨询师自动整理会议纪要并生成发票草稿的想法，但还没接触到用户。
请先查公开社区、竞品、抱怨和替代方案，判断值得继续、收窄还是停止。

## zh-discovery-plan

帮我招募八位真实用户，并设计一份不诱导的访谈提纲，重点追问这个问题最近一次
发生时他们实际怎么处理、花了什么成本。

## zh-landing-waitlist

产品还没开发。请写一个只有单一行动按钮的等待名单落地页，给出低成本引流计划，
以及明确的继续、调整和停止阈值。

## zh-prd-notes

把我的访谈摘要、竞品笔记和功能草稿整理成一份可直接执行的 MVP 产品需求文档，
明确范围、非目标、验收标准、风险和里程碑。

## zh-seo-live-url

根据我的线上 SaaS 网站和现有 PRD 做关键词研究，选一个现实的主关键词，并把
搜索意图、长尾词和页面目标整理成 SEO 执行方案。

## zh-none-code-fix

修复结账服务里失败的 TypeScript 单元测试，并运行相关测试套件。

## zh-none-architecture

为多租户订阅计费服务设计 D1 数据表和 Hono API 架构。

## zh-boundary-real-interviews

我有一个粗糙的产品想法，接下来想通过招募并访谈十位真实客户，了解他们过去
实际使用的工作流程和替代方案。

## zh-boundary-public-research

我有一个粗糙想法，但暂时联系不到客户。先用公开社区讨论和竞品证据判断它是否
值得进入更深入的用户研究。

## zh-boundary-waitlist-demand

用一个等待名单页面和少量真实流量来验证尚未开发的产品需求，并预先规定成功和
叫停阈值。
