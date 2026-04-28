import sys


def main() -> None:
    primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71]
    for prime in primes:
        print(f"? {prime}", flush=True)
        line = sys.stdin.readline()
        if not line:
            return
        g = int(line.strip())
        if g == 1:
            print(f"! {prime}", flush=True)
            return


if __name__ == "__main__":
    main()
