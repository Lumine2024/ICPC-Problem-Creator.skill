# A+B Problem

这是内部出题工作区，只用于题面维护、数据生成和本地验题。

## 运行

```powershell
./scripts/run-all-tests.ps1 -Workspace "examples/a-plus-b"
```

## 设计说明

- 本题是普通题，因此使用 `checker` 流程。
- 数据范围设置到 `10^18`，用于卡掉 `int` 溢出类错解。
- 隐藏数据包含负数、零、随机值和接近边界的大数。
- `solutions` 中保留了 `C++` 主解、第二标程和 Python 参考实现。
- `wrongSolutions` 中保留了两个典型错解，分别对应“32 位整型溢出”和“错误处理负数”。
