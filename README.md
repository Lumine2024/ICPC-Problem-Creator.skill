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

它会根据 `config.json` 编译 `generator + validator + main solution`，导出静态的 `.in/.ans` 文件到题目目录下的 `exported-tests/`。

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

## 仓库里有哪些核心内容

- `scripts/create-workspace.ps1`：创建新的题目工作区。
- `scripts/run-all-tests.ps1`：统一执行本地验证。
- `scripts/export-testdata.ps1`：把 `generator` 导出成可直接上传到 OJ 的静态数据文件。
- `scripts/templates/`：普通题、交互题和共享文件模板。
- `examples/`：可直接运行的示例题工作区。
- `SKILL.md`：让 AI Agent 稳定产出高质量题面、题解、数据的 agent skill。

如果你想要的是一个更工程化的 ICPC 出题起点，这个项目会比较合适。它的价值主要不在“自动生成多少代码”，而在于把出题过程中的文档、程序、数据和验证步骤收束到一套更稳定、可重复、可维护的本地工作流里。

更细的执行规范、交付要求和字段约束见 `SKILL.md`。

## 开源协议

MIT License

## 致谢

[testlib](https://github.com/MikeMirzayanov/testlib) 是很多 OJ 和出题流程中常用的评测库，为 generator、validator、checker 和交互程序提供了成熟支持。它同样采用 MIT 协议开源。
