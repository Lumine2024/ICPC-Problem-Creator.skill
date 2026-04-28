import math
import sys


def main() -> None:
    for prime in [2, 3, 5, 7, 11, 13, 17]:
        print(f"? {prime}", flush=True)
        line = sys.stdin.readline()
        if not line:
            return
        g = int(line.strip())
        if math.gcd(g, prime) == 1 and g == 1:
            print(f"! {prime}", flush=True)
            return

    print("! 97", flush=True)


if __name__ == "__main__":
    main()
