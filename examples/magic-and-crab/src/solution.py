import sys


def ask(y: int) -> int:
    print(f"? {y}", flush=True)
    return int(sys.stdin.readline())


def main() -> None:
    primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
    for p in primes:
        if ask(p) == 1:
            print(f"! {p}", flush=True)
            return
    print("! 2", flush=True)


if __name__ == "__main__":
    main()
