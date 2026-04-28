# 魔法与螃蟹

这是内部交互题工作区，只用于题面维护、本地联调和数据验证。

## 运行

```powershell
./scripts/run-all-tests.ps1 -Workspace "examples/magic-and-crab"
```

## `config.json`

- `interactive = true`，因此全局脚本会使用 interactor 流程。
- `generator.cases` 用 `type + seed` 复现隐藏值。
- `solutions` 包含主解、第二标程和 Python 参考实现。
- `wrongSolutions` 包含会在交互中被判错的典型错误策略。
