<div align=center>

# ICPC Problem Creator.skill

使用 AI Agent，根据一个 idea 一键出题，将那些繁琐的工作交给 AI，在单位时间里制造更多、更好的题。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![C++20](https://img.shields.io/badge/C%2B%2B-20-00599C?logo=c%2B%2B&style=flat-square)]

</div>

## 使用方法

安装：

```bash
git clone https://github.com/Lumine2024/ICPC-Problem-Creator.skill
cd ICPC-Problem-Creator.skill
npx skills add .
```

安装后，在Claude Code中这样调用：

```
这是某一题的雏形：（展示题面或给一个markdown），请根据这个雏形生成一个题目
```

## 特点

### 明确规则

`SKILL.md` 中包含了完整的规则链和 workflow 说明，明确的规则有利于 AI Agent 进行工作

### 脚本验证

`create-workspace.ps1`一键创建工作区，`run-all-tests.ps1`一键验证，减少 AI 幻觉，增加结果可信度

### 真实完整示例

`examples/*`是我真实出的若干个题，它们完整符合我的要求，可以作为 AI Agent 工作的参考

## 开源协议

MIT License

## 致谢

[testlib](https://github.com/MikeMirzayanov/testlib)是一个跨平台通用的评测库，提供了很多实用函数，是很多 OJ 上评测、交互、生成器的事实标准。它同样采用 MIT 协议开源。
