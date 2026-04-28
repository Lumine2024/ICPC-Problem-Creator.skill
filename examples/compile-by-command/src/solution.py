import sys


def solve_one(line: str) -> str:
    source = ""
    standard = "c++17"
    optimize = "None"
    output = "a.out"
    warnings = []

    for token in line.split():
        if token == "g++":
            continue
        if not token.startswith("-"):
            source = token
        elif token.startswith("-std="):
            standard = token[5:]
        elif len(token) > 2 and token[1] == "O":
            optimize = token[1:]
        elif len(token) > 2 and token[1] == "W":
            warnings.append(token[1:])
        elif len(token) > 2 and token[1] == "o":
            output = token[2:]

    warning_line = "None" if not warnings else " ".join(warnings)
    return "\n".join([source, standard, optimize, warning_line, output])


def main() -> None:
    t = int(sys.stdin.readline())
    answers = []
    for _ in range(t):
        answers.append(solve_one(sys.stdin.readline().rstrip("\n")))
    sys.stdout.write("\n".join(answers) + "\n")


if __name__ == "__main__":
    main()
