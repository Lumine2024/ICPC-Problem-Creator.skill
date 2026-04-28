# {{PROBLEM_TITLE}} Tutorial

## Summary

The hidden value `x` is in `[2, 100]`. A query `? y` returns `gcd(x, y)`. We need a final `z` in `[2, 100]` such that `gcd(x, z) = 1`.

## Strategy

Query a fixed list of small primes. If `gcd(x, p) = 1`, then `p` itself is already coprime to `x`, so answering `p` is valid immediately.

The scaffold solution checks `2, 3, 5, 7, 11, 13, 17` in order and stops at the first prime with gcd `1`.

## Correctness

If a queried prime `p` returns `1`, then by definition `gcd(x, p) = 1`. Printing `p` therefore satisfies the judge.

## Complexity

- Queries: at most `7`
- Time: `O(7 log 100)`
- Space: `O(1)`
