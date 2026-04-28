# {{PROBLEM_TITLE}}

This scaffold is a complete interactive toy problem. A hidden integer `x` satisfies `2 <= x <= 100`.

You may issue up to `7` queries of the form `? y`, where `2 <= y <= 100`. The interactor replies with `gcd(x, y)`.

When you are ready, output `! z` with `2 <= z <= 100`. Your answer is accepted if `gcd(x, z) = 1`.

## Interaction Protocol

- Print `? y` and flush to receive `gcd(x, y)`.
- Print `! z` and flush to finish.
- Your program must stop after printing the final answer.

## Sample

```input1
4
3
2
1
```

```output1
? 2
? 3
? 5
? 7
! 7
```

## Explanation

The sample transcript corresponds to a hidden value divisible by `2` and `3`, but coprime to `7`.
