import sys


def main() -> None:
    data = sys.stdin.readline().strip()
    n = int(data)
    sys.stdout.write(f"{n}\n")


if __name__ == "__main__":
    main()
