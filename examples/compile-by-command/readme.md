# 命令行编译

这是内部出题工作区，只用于题面维护、数据生成和本地验题，不用于目标 OJ 提交。

## 运行

```powershell
./scripts/run-all-tests.ps1 -Workspace "examples/compile-by-command"
```

## `config.json`

- `generator.cases` 提供 20 份以上的多组数据文件，覆盖默认值、乱序 token、大量空格、长行和接近上界的大数据。
- `checker` 按行读取并按 token 比较，允许行尾多余空格，但要求语义输出完全一致。
- `solutions` 包含主解、第二标程和 Python 参考实现。
- `wrongSolutions` 覆盖默认值、空格切分、警告顺序和源文件识别等典型错误。
