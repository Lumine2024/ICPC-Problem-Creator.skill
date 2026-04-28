import sys


def main() -> None:
    data = sys.stdin.buffer.read().split()
    if not data:
        return
    a = int(data[0])
    b = int(data[1])
    sys.stdout.write(f"{a + b}\n")


if __name__ == "__main__":
    main()
