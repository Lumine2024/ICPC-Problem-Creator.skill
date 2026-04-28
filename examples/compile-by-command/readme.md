# 命令行编译

这是内部出题工作区，只用于题面维护、数据生成和本地验题，不用于目标 OJ 提交。

## 运行

```powershell
./scripts/run-all-tests.ps1 -Workspace "examples/compile-by-command"
```

## `config.json`

- `generator.cases` 描述了样例、边界和随机数据。
- `checker` 使用基于 token 的比较逻辑。
- `solutions` 包含主解、第二标程和 Python 参考实现。
- `wrongSolutions` 包含会在默认标准或默认输出文件上犯错的典型错解。
