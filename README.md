<div align=center>

# ICPC Problem Creator.skill

把一个题目 idea 落成可迭代、可本地验证的 ICPC 出题工作区。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![C++20](https://img.shields.io/badge/C%2B%2B-20-00599C?logo=c%2B%2B&style=flat-square)](https://isocpp.org/)
[![PowerShell7](https://img.shields.io/badge/PowerShell-7.X-blue?logo=powershell)](https://learn.microsoft.com/en-us/powershell/)

</div>

## 这是什么

`ICPC Problem Creator.skill` 用来帮助出题人把一个初始想法逐步整理成完整的本地题目工程。它面向的不是线上评测平台，而是出题阶段的内部生产流程：题面、题解、标程、数据生成器、数据校验器、checker 或 interactor，以及一套可以反复执行的本地验证流程。

这个项目的核心目标不是“生成一堆文件”，而是让题目在本地形成一个更稳定的工作闭环：能生成、能检查、能复现、能继续修改。

## 适合什么场景

- 你已经有一个题目想法，但还没有整理成完整工程。
- 你希望普通题和交互题都使用统一的本地工作流。
- 你想把题面、程序和测试数据放在同一个可维护目录里。
- 你需要反复生成数据、跑参考解、筛错解，而不想为每道题临时拼脚本。

## 它能做什么

- 根据题目 idea 创建标准化的本地工作区。
- 为普通题和交互题生成对应的基础目录与模板。
- 使用统一的 `config.json` 描述题目的本地验证方式。
- 通过脚本批量编译解答、生成器、validator、checker 或 interactor。
- 自动生成测试数据，并在本地跑通参考解与错解验证。
- 帮助出题过程从“零散文件”转成“可重复执行的工程”。

## 为什么要使用该 Skill

出题事故往往不是因为“少写了一份代码”，而是因为整个验证链条没有闭合。

一个非常典型的反例，就是 2026 年 CCPC 贵州邀请赛中的这道“娄山关扫雷”。这道题出现了很大争议：官方 `std` 实际上是一个“把地雷尽量压成角落矩形”的错误贪心。结果一方面放过了大量本来应该被卡掉的错误做法，另一方面又把大量真正正确的做法卡掉了。它不是一个单纯的实现失误，而是一次很典型的流程失守：

- 正解没有被独立交叉验证到足够可信。
- 错解没有被系统性枚举并真正拿数据去卡。
- 数据没有围绕关键错误思路定向构造。
- 最终提交到赛场的“标准程序”，没有经过足够严格的本地回归。

这类事故会直接伤害比赛公信力，也会让本来正确的选手承受完全不必要的损失。它提醒我们，命题不能只停留在“题意大致合理”或“我觉得这个做法应该对”，而必须尽量做到下面三件事同时成立：

- 数据强大：不是只有随机数据，而是有意识地围绕错误思路构造 hack。
- 正解正确：最好有主解和独立参考解，互相校验，而不是只信一份代码。
- 错解真错：不要只在纸面上说“这题能卡某某做法”，而要真的把错解写出来、编译它、运行它、看它是否被数据打死。

这个 skill 的设计初衷，恰恰就是把这些要求变成一个默认工作流，而不是靠命题人临场记忆：

- 用 `config.json` 把题目的验证链条固定下来，避免“这次先手跑一下，下次再补”。
- 要求 generator、validator、checker / interactor、主解、参考解、错解、题解一起落地。
- 通过 `scripts/run-all-tests.ps1` 统一编译、生成、校验、跑主解、跑参考解、跑错解。
- 鼓励为关键错误思路准备多个真实可编译的 wrong solution，而不是只写几句说明。

前面这个“娄山关扫雷”示例，就是一个很直接的说明：我实际使用 Codex 运行了该 Skill，喂给它题面，Codex 正确生成了正确的动态规划做法，交叉验证可以通过，而在没有提前告知有“贪心”错解的前提下，Codex 正确使用了本仓库下[生成错解的方法论](subskills/wrong-gen/references/mistake-taxonomy.md)，成功卡掉了该错解。这件事本身就说明，只要命题流程足够规范，很多原本会在赛场上爆炸的问题，其实在本地阶段就能提前暴露。

如果你不准备使用 AI 参与命题，这份规范化的工作流相当于本地 Polygon，它会督促你完整编写 checker/validator/solution/wrong solution 等部分，可以对你的命题规范化起到关键作用。此外，[SKILL.md](SKILL.md)、[生成错解与数据的子 SKILL](subskills/wrong-gen/SKILL.md) 等文档也提供了大量可参考的命题方法论，阅读它们可以帮助你更好的命题。

如果你准备使用 AI 参与命题，那么更需要这种规范化工作流。AI 当然能帮你补题面、写代码、列错解、搭数据，但它也同样可能一本正经地产出“看起来很像对的错误程序”。这时候，重要的不是“AI 写得快不快”，而是它是否被放进了一套足够严格的验证框架里。

换句话说，这个 skill 的价值，不只是帮你“更快造题”，更是帮你把 AI 命题过程约束得更规范，尽量减少出锅概率，尽量减少下一次“贵州站悲剧”。

## 主要优点

### 1. 工作流统一

不同题目不必各自维护一套零散脚本。题目的本地验证流程由统一入口驱动，迁移、接手和回溯都会更轻松。

### 2. 结果更容易复现

测试数据、参考解和验证逻辑都放在同一工作区内，减少“这份数据是怎么来的”或“上次怎么跑通的”这类信息丢失。

### 3. 更适合持续迭代

出题很少一次成型。你可能会改题意、调数据范围、补错解、重写 checker。这个项目的结构更适合反复调整，而不是一次性打包。

### 4. 降低遗漏关键组件的概率

完整题目通常不只有题面和标程，还需要 generator、validator、checker、错解、题解等配套内容。这个项目鼓励把这些组件一起维护，而不是临近交付再补。

## 可能的局限性

### 1. 它不替代题目设计能力

这个项目可以帮你组织产物和验证流程，但不能替你保证题目本身有趣、平衡、不卡常、不卡实现细节，也不能自动判断题目是否适合比赛。

### 2. 生成结果仍然需要人工审阅

即使工作区已经能跑通，也不代表题面没有歧义、数据没有漏洞、错解覆盖足够全面，或者参考实现真的足够独立。关键内容仍然需要出题人自己把关。

### 3. 重点是本地出题流程，不是线上平台集成

这个仓库不负责目标 OJ 的提交流程、平台专属元数据或 git 驱动的评测链路。如果你的主要需求是对接某个具体平台，还需要额外适配。

### 4. 当前能力更偏向标准化工程

如果你的团队已经有一套成熟且高度定制的出题流水线，这个项目未必能无缝替代，更多时候会更适合作为统一模板或参考基线。

## 使用方式

### 手动造题

先创建题目工作区：

```powershell
# 传统题
./scripts/create-workspace.ps1 -Name "example-problem"
# 交互题
./scripts/create-workspace.ps1 -Name "example-interactive" -Interactive
```

编写题意、题解、数据等后，再运行本地验证：

```powershell
./scripts/run-all-tests.ps1
./scripts/run-all-tests.ps1 -Workspace "examples/example-problem"
./scripts/export-testdata.ps1 -Workspace "examples/example-problem"
```

如果目标 OJ 不支持本地 `generator`，可以再执行一次：

```powershell
./scripts/export-testdata.ps1 -Workspace "examples/example-problem"
```

它会根据 `config.json` 导出测试数据到题目目录下的 `exported-tests/`：

- 普通题导出静态的 `.in/.ans` 文件。
- 交互题导出供 interactor 使用的原始 `.interactor.in` 文件。

### 使用 AI Agent 自动造题

先安装：

```bash
git clone https://github.io/Lumine2024/ICPC-Problem-Creator.skill.git
cd ICPC-Problem-Creator.skill
npx skills add .
```

安装后，在 Claude Code / Codex / VSCode / OpenClaw 等支持 Agent 的编辑器中，直接输入你的要求

```
> 请生成一个 a+b problem
```

等待 AI Agent 生成完毕后，即可在仓库的 `examples/{{题目名字}}` 内找到该题目。

如果你想先看成品结构和验证方式，可以直接参考 `examples/` 目录里的示例题。

### 导出为 Hydro 风格的 zip 文件

请确保模块 `powershell-yaml` 已安装。

```powershell
./scripts/export-hydrozip.ps1 -Workspace "examples/example-problem"
```

## 仓库里有哪些核心内容

- `scripts/create-workspace.ps1`：创建新的题目工作区。
- `scripts/run-all-tests.ps1`：统一执行本地验证。
- `scripts/export-testdata.ps1`：导出普通题静态数据，或导出交互题喂给 interactor 的原始数据文件。
- `scripts/templates/`：普通题、交互题和共享文件模板。
- `examples/`：可直接运行的示例题工作区。
- `SKILL.md`：让 AI Agent 稳定产出高质量题面、题解、数据的 agent skill。

如果你想要的是一个更工程化的 ICPC 出题起点，这个项目会比较合适。它的价值主要不在“自动生成多少代码”，而在于把出题过程中的文档、程序、数据和验证步骤收束到一套更稳定、可重复、可维护的本地工作流里。

更细的执行规范、交付要求和字段约束见 `SKILL.md`。

## 开源协议

MIT License

## 致谢

[testlib](https://github.com/MikeMirzayanov/testlib) 是很多 OJ 和出题流程中常用的评测库，为 generator、validator、checker 和交互程序提供了成熟支持。它同样采用 MIT 协议开源。
