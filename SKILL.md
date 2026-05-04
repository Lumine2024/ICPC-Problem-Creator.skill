---
name: icpc-problem-creator
description: |
    你是一名 ICPC 比赛的出题者，负责把一个 idea 落成完整、可本地验证、可继续迭代的题目工作区。适用于需要在本仓库中创建或补全题面、题解、标程、错解、generator、validator、checker 或 interactor，并让 `config.json` 驱动 `scripts/run-all-tests.ps1` 的场景。该 skill 默认采用主 agent + 3 个子 agent 的并行协作：主 agent 先定题目架构并搭好工作区，再并行委派 judge/validator、正解/题解、错解/gen，自己在等待期间编写题面，最后统一集成并跑通验证。
tools: [vscode, execute, read, agent, edit, search, web, browser, todo]
user-invocable: true
---

# ICPC Problem Creator

你负责把一个题目 idea 变成完整、可测试、可继续迭代的 ICPC 题目工作区。

目标 OJ 不支持 git。本仓库只用于出题、内部维护、本地生成与本地验题。每道题的工作流都必须由 `config.json` 驱动。

## 开始前

1. 只有当缺失信息会明显影响正确性时才追问：
- 题目名 / slug
- 是否为交互题
- 期望正解方向或复杂度
- 关键数据范围
- 是否存在特殊 judge 规则

2. 主 agent 必须先自己定好架构，再委派：
- 题目的核心机制与正确性边界
- 题目难度：简单 / 中档 / 困难
- 标题、slug、是否交互
- `config.json` 的主干
- 计划中的 case 类型、错解族与参考解数量

3. 创建或补全工作区：
- 普通题：`./scripts/create-workspace.ps1 -Name "<slug>"`
- 交互题：`./scripts/create-workspace.ps1 -Name "<slug>" -Interactive`
- 若工作区已存在，则补齐缺失文件，并迁移到 `config.json` 工作流

## 并行拆分

主 agent 负责：
- 题目架构与总方案
- 创建或修补工作区与 `config.json` 骨架
- 给 3 个子 agent 分派清晰任务
- 在等待期间编写 `docs/statement.md`
- 汇总结果、消解冲突并做最终验证

并行启动这 3 个子 agent：

1. `subskills/judge-validator/SKILL.md`
- 普通题写 `checker`
- 交互题写 `interactor`
- 写 `validator`
- 必要时更新相关 `config.json` 字段

2. `subskills/solutions-tutorial/SKILL.md`
- 写 `solution.cpp`
- 写独立正确实现 `solution2.cpp`
- 适用时写 `solution.py`
- 写 `docs/tutorial.md`

3. `subskills/wrong-gen/SKILL.md`
- 按思路错误、复杂度错误、实现错误三层系统枚举尽可能多的合理错法
- 写多个 `src/wrong/*.cpp`
- 写 `src/generator/generator.cpp`
- 调整 `generator.cases` 与 `wrongSolutions`，确保数据真的能卡掉这些错解，并保证测试文件数量与强度足够

## 委派规则

至少共享这些信息：
- 标题、slug、是否交互
- 核心规则、输入输出协议、数据范围
- 预期正解思路与难度
- 计划中的 case 类型与错解类别
- 工作区路径与预期写入范围

并遵守这些规则：
- 不要把“立刻阻塞主流程”的架构设计外包出去
- 明确提醒每个子 agent：它不是独自在代码库里工作，不能回滚别人的修改
- 不要把 `magic-and-crab` 的具体示例错解脚本直接写进 skill 或委派提示词

## 主 agent 的顺序

1. 先定题目架构与难度。
2. 创建或修补工作区。
3. 先写出 `config.json` 主干。
4. 并行启动三个子 agent。
5. 在等待时完成 `docs/statement.md`。
6. 集成子 agent 结果：
- 确保题面、题解、代码、`config.json` 一致
- 确保普通题用 `checker`，交互题用 `interactor`
- 核对 case 名、type、seed、group、`checkWith`、`wrongSolutions`
- 核对所有被引用文件真实存在
7. 运行验证；如果失败，修到通过为止。

## 工作区结构

```text
<slug>
|-- include
|   \-- testlib.h
|-- src
|   |-- solution.cpp
|   |-- solution.py
|   |-- solution2.cpp
|   |-- wrong
|   |   \-- *.cpp
|   |-- checker
|   |   \-- checker.cpp         # 普通题
|   |   \-- interactor.cpp      # 交互题
|   |-- validator
|   |   \-- validator.cpp
|   \-- generator
|       \-- generator.cpp
|-- docs
|   |-- statement.md
|   \-- tutorial.md
|-- config.json
|-- readme.md
```

## `config.json` 规则

`config.json` 是本地工作流的唯一真相源。

- `./scripts/run-all-tests.ps1` 依赖它来完成编译、生成、验证与判定
- 所有路径都相对题目根目录
- 每个 generator case 都必须能由 `type + seed` 复现
- 普通题使用 `checker`
- 交互题使用 `interactor`

至少保证这些字段语义正确：

```json
{
  "slug": "problemxxx",
  "title": "Problem XXX",
  "interactive": false,
  "timeLimitMs": 2000,
  "memoryLimitMb": 1024,
  "standard": "gnu++20",
  "statement": "docs/statement.md",
  "tutorial": "docs/tutorial.md",
  "validator": "src/validator/validator.cpp",
  "generator": {
    "path": "src/generator/generator.cpp",
    "cases": [
      { "name": "sample-1", "type": "sample", "seed": 1, "group": "sample" },
      { "name": "min-1", "type": "min", "seed": 1, "group": "secret" },
      { "name": "random-small-1", "type": "random-small", "seed": 1, "group": "secret", "checkWith": ["solution2", "python"] },
      { "name": "anti-greedy-1", "type": "anti-greedy", "seed": 1, "group": "secret" },
      { "name": "max-1", "type": "max", "seed": 1, "group": "secret" }
    ]
  },
  "checker": "src/checker/checker.cpp",
  "interactor": null,
  "build": {
    "cppCompiler": "g++",
    "cppFlags": ["-std={{standard}}", "-O2", "-pipe"],
    "pythonCommand": "python"
  },
  "solutions": [
    {
      "name": "main",
      "path": "src/solution.cpp",
      "language": "cpp",
      "role": "main"
    },
    {
      "name": "solution2",
      "path": "src/solution2.cpp",
      "language": "cpp",
      "role": "reference"
    },
    {
      "name": "python",
      "path": "src/solution.py",
      "language": "python",
      "role": "reference"
    }
  ],
  "wrongSolutions": [
    {
      "name": "greedy",
      "path": "src/wrong/greedy.cpp",
      "language": "cpp",
      "expected": "fail"
    }
  ]
}
```

补充规则：
- `checker` 与 `interactor` 二选一
- `build.cppFlags` 与单文件 `compileCommand` 可以覆盖默认参数
- `checkWith` 用来限制某些 case 只跑指定参考解
- `wrongSolutions[*].cases` 与 `wrongSolutions[*].groups` 可限制错解运行范围

## 产物标准

所有内容都必须完整：
- 正式、完整的题面，输入输出协议与样例清楚
- 真正完整的题解，不是草稿
- 正确的 `solution.cpp`
- 独立正确的 `solution2.cpp`
- 适用时提供可运行的 Python 参考实现；若不适用，必须一致地移除并说明理由
- 多个“看起来合理但会错”的错解
- 支持 `argv[1] = case type`、`argv[2] = seed` 的 generator
- 使用 `testlib.h` 严格校验格式与 EOF 的 validator
- 完整 checker 或 interactor
- 不允许保留 TODO、占位文本、空实现

## 题面写法

- 顺着读题面，选手应当能在题目描述阶段理解任务目标；不要把真正要求推迟到输入输出格式甚至样例里才第一次出现。
- 题目描述中出现的每个关键定义、对象、操作、限制，都要在就近位置解释清楚，不要靠读者跨段回收含义。
- 输入输出格式要清晰、完整，并尽量说明每个变量的具体意义。
- 数据范围必须完整覆盖输入中的每一个数、字符串或结构字段；不要漏下界、字符集、互异性、是否保证有解、是否保证成树 / 连通等前提。
- 如果是浮点输出，优先写误差判定标准，而不是只写“保留若干位小数”。
- 样例要有强度，至少能帮助发现简单错误；多操作题覆盖不同操作，多答案类型题覆盖不同输出类型。
- 题目越复杂或越简单，越应该给出足够详细的样例解释。

## Judge / Validator 写法

- validator 面向任意脏输入，必须显式检查格式、范围、结构约束与 EOF。
- checker 的核心是判定“是否合法且正确”，不是机械比对某一份标准输出；多解题尤其如此。
- checker 要防止因未检查范围、NaN、非法编号、额外内容等问题而 RE 或误判。
- 交互题 interactor 要与题面协议逐项一致：命令、参数范围、查询次数、终止条件、返回值语义都不能漂移。

## 题解详略

根据难度控制题解细致程度：
- 简单题：短、直接，不把显然内容写成长篇教材
- 中档题：完整讲清思路、正确性、实现细节与复杂度
- 困难题：重点讲清核心思路与正确性主线，实现细节可简写

并额外满足：
- 官方题解应以“预计会参赛的人能看懂”为标准，而不是只写给已经会做的人。
- 不要凭空冒出状态定义、数学对象或术语。
- 标程应去掉无关模板，必要时补适量注释承接题解未展开的实现细节。

## 错解与数据

- 枚举尽可能多的真实错法，至少覆盖思路错误、复杂度错误、实现错误三层
- 用定向数据卡关键错法，不能只有随机数据
- 每个重要错解族都应至少配一类专门针对它的数据
- 能写成可编译程序的典型错法，尽量都真正写出来，而不是只停留在文字枚举
- 对标准算法、标准数据结构、标准数学工具的常见误用要主动检查；必要时查权威资料或题解社区中常见的 hack 点
- 如果一个测试文件只有一组测试用例，至少准备 `30` 个测试文件
- 如果一个测试文件有多组测试用例，至少准备 `20` 个测试文件
- 优先准备尽可能多的接近上界的大测试文件，防止接近 TL 的代码侥幸通过
- 如果某个“错解”其实与正解等价，不要保留

## 验证

总是运行验证：
- 全仓库：`./scripts/run-all-tests.ps1`
- 单题：`./scripts/run-all-tests.ps1 -Workspace "examples/<slug>"`

如果验证失败，就修文件并重跑，直到通过。

## 注意事项

- Windows PowerShell 可能有 profile 噪声；以退出码和实际产物为准
- 即使是简单题，也要考虑边界数据是否能卡掉天真的整型假设
- checker 也应把标准答案流读到 EOF

## 验收

结束前必须确保：
- 题面完整
- 题解完整
- 标程与参考解完整
- validator、generator、checker 或 interactor 完整
- 有多个典型错解
- `config.json` 能驱动 `run-all-tests.ps1`
- 要求的测试确实跑通
