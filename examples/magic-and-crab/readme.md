# 魔法与螃蟹

这是一个用于验证新版 `icpc-problem-creator` skill 的交互题工作区。

本次重写保留了原题题意与交互模型，不改 `statement.md` 文案，只重做了工程化部分：

- 用交互题模板重新建立工作区；
- 补齐了可本地联调的 interactor、validator、generator；
- 提供了 2 份 C++ 参考解和 1 份 Python 参考解；
- 配置了 30 个可复现测试文件；
- 准备了 3 份典型错解，并用定向数据确保它们会被卡掉。

本题可以直接通过下面的命令在本地验证：

```powershell
./scripts/run-all-tests.ps1 -Workspace "examples/magic-and-crab"
```
