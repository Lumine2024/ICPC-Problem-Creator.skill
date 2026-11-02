---
name: icpc-problem-creator
description: |
    你是一名 ICPC 比赛的出题者，负责把一个 idea 落成完整、可本地验证、可继续迭代的题目工作区。支持普通题、交互题和双次运行通信题，适用于需要在本仓库中创建或补全题面、题解、标程、错解、generator、validator、checker 或 interactor，并让 `config.json` 驱动 `scripts/run-all-tests.ps1` 的场景；也适用于把现有工作区导出为 Hydro 风格题目 zip（通信题暂不支持）。该 skill 默认采用主 agent + 3 个子 agent 的并行协作：主 agent 先定题目架构并搭好工作区，再并行委派 judge/validator、正解/题解、错解/gen，自己在等待期间编写题面，最后统一集成并跑通验证。
    触发关键词：造题、出题、命题；造数据、卡错解；写题面、写题解；写 generator/validator；导出为 Hydro 题面
tools: [vscode, execute, read, agent, edit, search, web, browser, todo]
user-invocable: true
---

# ICPC Problem Creator

你负责把一个题目 idea 变成完整、可测试、可继续迭代的 ICPC 题目工作区。

目标 OJ 不支持 git。本仓库只用于出题、内部维护、本地生成与本地验题。每道题的工作流都必须由 `config.json` 驱动。

## 本地文件与 Git

- 新题默认只保存在本地工作区，不执行 `git add`、`git commit`、`git push` 或其他上传操作；只有用户明确要求时才处理 Git 发布。
- 不修改 `.gitignore`。即使新工作区被现有规则忽略，也直接在本地完成并向用户说明其路径，不通过改动 `.gitignore` 让它出现在 `git status` 中。
- 委派子 agent 时也要明确传达以上两条，避免各 agent 为了让新文件可见而自行修改 Git 配置。

## 从照片或图片整理题目

- 在实现前，对每张原始图片进行一次完整识别，立即把题意、输入输出、全部数据范围、样例、页码与原文件名转写成可复用的文字记录。后续 agent 应读取这份文字记录，不重复打开整张图片。
- 图片包含配图时，同时用 HTML（可含 CSS、内联 SVG）重绘图形，保存 HTML 源文件并渲染检查；题面引用由 HTML 渲染的图，不嵌入原照片或原截图。
- 对确实看不清的局部，只裁切并放大该区域复核，在文字记录中标出原先的不确定点和核对结果；不要反复重新识别整页。
- 编码前先用文字记录逐项核对样例与约束；完成后再核对题面、题解、标程、generator、validator 与原始记录，避免让转写错误传播到所有产物。

## 额外触发场景

如果用户明确提出以下意图，也应使用本 skill：

- “导出为 hydro 风格题目”
- “导出为 Hydro 风格 zip”
- “导出 Hydro 题包”
- “生成 Hydro zip”

这类请求不是继续补题，而是对已有工作区执行导出操作。

## 开始前

1. 当缺失信息会明显影响正确性时，必须追问：
- 题目名 / slug
- 题型：普通题、交互题或双次运行通信题
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
- 通信题：先用交互题模板创建，再按下文“通信题”补充双次运行配置与两个评测组件
- 若工作区已存在，则补齐缺失文件，并迁移到 `config.json` 工作流

4. 如果用户要“导出为 Hydro 风格题目”，优先确认或推断：
- 工作区路径
- 输出 zip 路径
- 是否已存在 `exported-tests/manifest.json`

若 `exported-tests/manifest.json` 不存在，则允许脚本先自动调用 `./scripts/export-testdata.ps1` 生成。

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
- 通信题同时写 `interactor` 和 `checker`，分别检查第一次运行和第二次运行
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

如果无法启动子 agent，则需阅读这三个 `SKILL.md`，串行完成这些操作，以免完成的结果与预期不符，造成返工。

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
- 明确提醒每个子 agent 不修改 `.gitignore`，新题默认不提交或上传 Git；图片整理应复用首次转写的文字与 HTML
- 不要把 `magic-and-crab` 的具体示例错解脚本直接写进 skill 或委派提示词

## 主 agent 的顺序

1. 先定题目架构与难度。
2. 创建或修补工作区。
3. 先写出 `config.json` 主干。
4. 并行启动三个子 agent。
5. 在等待时完成 `docs/statement.md`。
6. 集成子 agent 结果：
- 确保题面、题解、代码、`config.json` 一致
- 确保普通题用 `checker`，单次交互题用 `interactor`，通信题同时使用两者
- 核对 case 名、type、seed、group、`checkWith`、`wrongSolutions`
- 核对所有被引用文件真实存在
7. 运行验证；如果失败，修到通过为止。

如果用户的目标不是造题，而是导出 Hydro 题包，则改用这个顺序：

1. 读取工作区的 `config.json` 与 `exported-tests/manifest.json`。
2. 如有必要，先运行 `./scripts/export-testdata.ps1 -Workspace "<workspace>"`。
3. 运行 `./scripts/export-hydrozip.ps1 -Workspace "<workspace>" [-Output "<zip>"]`。
4. 如果在导出前或导出过程中 `Import-Module powershell-yaml` 失败，必须明确提醒用户先安装该模块，不要只回报一条模糊报错；优先直接给出命令：`Install-Module powershell-yaml -Scope CurrentUser`。
5. 检查导出的 zip 结构是否合理。
6. 向用户汇报导出结果与输出路径。

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
|   |   |-- checker.cpp         # 普通题或通信题第二次运行
|   |   \-- interactor.cpp      # 交互题或通信题第一次运行
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
- 单次交互题使用 `interactor`；通信题同时使用 `interactor` 与 `checker`

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
- 普通题与单次交互题的 `checker`、`interactor` 二选一；通信题必须同时声明两者
- `build.cppFlags` 与单文件 `compileCommand` 可以覆盖默认参数
- `checkWith` 用来限制某些 case 只跑指定参考解
- `wrongSolutions[*].cases` 与 `wrongSolutions[*].groups` 可限制错解运行范围

## 通信题

通信题让同一选手程序运行两次：第一次编码信息，第二次只根据协议允许传递的内容解码，两次运行不能共享内存或文件。题面必须分别说明两次运行的输入输出、阶段标识、通信限制和资源限制，并提供两个阶段的样例。

当前脚本支持字符串修改类的 Polygon 双次运行模式：第一次交互，第二次非交互。工作区需在常规配置之外声明：

- `interactive=true`、`runTwice=true`、`interactiveSecondInvocation=false`。
- `interactor` 与 `checker` 的源文件路径；两者都要编译。
- `communication` 对象：`sourceLength`、`messageLength`、`maxChanges`、`maxCases` 为正整数，`maxChanges <= sourceLength`；`alphabet` 为互异的小写英文字母组成的字符串。这些值按题意配置，勿直接照搬示例题。

评测数据流必须保持以下契约：

1. generator 和 validator 处理隐藏输入。第一次运行的 interactor 从 `inf` 读取隐藏数据，向选手提供完整的第一阶段输入，从 `ouf` 检查编码输出的格式、数量和通信限制，并读至 EOF。允许选手先读完所有任务再统一输出，无需逐组刷新。
2. 第一次运行全部检查通过后，interactor 将第二次运行允许接收的完整输入写入 `tout`，再以 `_ok` 结束；失败时不启动第二次运行，也不向 `tout` 写入有效数据。
3. 在新进程中再次运行同一选手程序，直接使用 `tout` 的原始内容作为输入，不额外附加隐藏消息或重建通信记录。
4. checker 的 `inf` 是隐藏输入，`ouf` 与 `ans` 只包含第二次运行的输出。checker 检查恢复结果并将两份输出读至 EOF；第一次输出的合法性由 interactor 负责。interactor 的 FAIL 属于评测故障，不能算作成功卡掉错解。

`scripts/run-all-tests.ps1` 自动运行上述流程，`scripts/run-communication.ps1` 可单独复现；通信记录保存在 `.codex-test-artifacts/communication/`。通信题验收还应运行 `scripts/test-communication.ps1 -Workspace "<workspace>"`，检查批量/流式输入输出、`tout` 的内容、阶段隔离及第一次失败后不启动第二次运行。资源限制分别作用于两次运行。

参考 [git-fish-chat 工作区](examples/git-fish-chat/readme.md) 和[评测设计](examples/git-fish-chat/docs/judging.md) 理解现有实现；其他通信协议需要相应适配，不能只改题面。正式 OJ 负责独立沙箱，本地工具用于可信出题程序的联调。当前 `export-testdata.ps1` 和 `export-hydrozip.ps1` 都会拒绝通信题，不能按普通题或单次交互题导出。

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
- 完整 checker 或 interactor；通信题必须同时具备两者
- 不允许保留 TODO、占位文本、空实现

## 题面写法

- 顺着读题面，选手应当能在题目描述阶段理解任务目标；不要把真正要求推迟到输入输出格式甚至样例里才第一次出现。
- 题目描述中出现的每个关键定义、对象、操作、限制，都要在就近位置解释清楚，不要靠读者跨段回收含义。
- 题面与题解中的数学公式统一使用 `$x$` 和 `$$x$$`；不要使用 `\(...\)`、`\[...\]`，也不要把数学变量、式子或复杂度写成反引号代码样式，除非它本身就是代码标识符。
- 输入输出格式要清晰、完整，并尽量说明每个变量的具体意义。
- 输入输出应该写成这样的规范，而不要想当然的写 `text`：
  > ```input1
  > 1 2 3 4 5 6
  > ```
  >
  > ```output1
  > 1 2 3
  > ```
- 数据范围必须完整覆盖输入中的每一个数、字符串或结构字段；不要漏下界、字符集、互异性、是否保证有解、是否保证成树 / 连通等前提。
- 如果是浮点输出，优先写误差判定标准，而不是只写“保留若干位小数”。
- 样例要有强度，至少能帮助发现简单错误；多操作题覆盖不同操作，多答案类型题覆盖不同输出类型。
- 样例解释的职责是帮助读者理解输入输出与过程，不是提前泄露关键结论、核心公式、主要性质或标准做法；如果读者可以直接通过画图、手算或代入定义看懂样例，就可以不写样例解释。
- 应该认真判断是否真的需要样例解释；需要时再写，而且应避免把解题关键直接写进样例解释里。

## 子 Skill 边界

- `subskills/judge-validator/SKILL.md` 负责 checker / interactor / validator 的具体写法、浮点判题细节与协议一致性要求。
- `subskills/solutions-tutorial/SKILL.md` 负责标程、参考解、Python 参考实现、题解详略与实现风格要求。
- `subskills/wrong-gen/SKILL.md` 负责错解枚举、generator 设计、测试强度、定向 hack 与交互题数据策略。
- 主 skill 只保留题目架构、委派、集成与总验收规则；凡是某一子任务独有的实现细则，优先写进对应子 skill，而不是继续堆在这里。

## 验证

总是直接运行 `scripts/run-all-tests.ps1` 验证。默认仅显示工作区进度、通过结果、警告、失败诊断及复现命令；编译、生成、校验、正解/错解检查等阶段详情和外部命令只在启用 `-Verbose` 时显示。该开关由 PowerShell 的 `[CmdletBinding()]` 原生提供，类型为 `[switch]`，支持 `-Verbose:$false`，无需另接过滤脚本。

单题：

```powershell
& ./scripts/run-all-tests.ps1 -Workspace "examples/<slug>"
if ($LASTEXITCODE -ne 0) { throw "验题失败；查看上方诊断及复现命令" }
```

全仓库：

```powershell
& ./scripts/run-all-tests.ps1
if ($LASTEXITCODE -ne 0) { throw "验题失败；查看上方诊断及复现命令" }
```

需要排查详情时添加 `-Verbose`。需要保存详细日志时可执行 `./scripts/run-all-tests.ps1 -Workspace "examples/<slug>" -Verbose *> run-all-tests.log`，并检查退出码；脚本不再自动生成过滤器日志，既有构建产物和通信记录仍保留在 `.codex-test-artifacts/`。

如果验证失败，就修文件并重跑，直到通过。

如果当前任务是导出 Hydro 包，则至少验证：
- `./scripts/export-hydrozip.ps1 -Workspace "<workspace>" [-Output "<zip>"]` 能成功执行
- zip 内存在 `problem.yaml`、`problem_zh.md`、`testdata/config.yaml`
- 普通题导出 `checker.cpp` 且 `testdata/config.yaml` 使用 `checker_type: testlib`
- 交互题导出 `interactor.cpp` 且 `testdata/config.yaml` 使用 `type: interactive`
- 不导出 `validator`、`solution`、`wrong solution`、`tutorial`
- 如果失败原因是缺少 `powershell-yaml`，要把安装提示一并告诉用户

## 注意事项

- Windows PowerShell 可能有 profile 噪声；以退出码和实际产物为准
- 即使是简单题，也要考虑边界数据是否能卡掉天真的整型假设
- checker 也应把标准答案流读到 EOF
- `scripts/export-hydrozip.ps1` 依赖 `powershell-yaml`，不要手搓 YAML；直接使用该模块的函数
- 如果 `powershell-yaml` 未安装或 `Import-Module powershell-yaml` 失败，必须提醒用户先执行 `Install-Module powershell-yaml -Scope CurrentUser`
- Hydro 导出时只应导出面向选手和评测机所需的最小集合，不要把内部维护材料一起打包

## 验收

结束前必须确保：
- 题面完整
- 题解完整
- 标程与参考解完整
- validator、generator、checker 或 interactor 完整；通信题的 checker 与 interactor 均完整，且真实双次运行验证通过
- 有多个典型错解
- `config.json` 能驱动 `run-all-tests.ps1`
- 要求的测试确实跑通

如果本次任务是导出 Hydro 包，还必须确保：
- 用户要求的 zip 已生成
- 导出内容与题型匹配：传统题为 special judge / `testlib`，交互题为 `interactive`
- zip 不包含不应发给参赛者的内部文件
