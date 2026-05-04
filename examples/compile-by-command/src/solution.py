import sys


def parse_command(line: str):
    tokens = line.split()
    source = ""
    standard = "c++17"
    optimization = "None"
    warnings = []
    output = "a.out"

    for token in tokens[1:]:
        if token.startswith("-std="):
            standard = token[5:]
        elif token.startswith("-O"):
            optimization = token[1:]
        elif token.startswith("-W"):
            warnings.append(token[1:])
        elif token.startswith("-o"):
            output = token[2:]
        else:
            source = token

    return source, standard, optimization, warnings, output


def main() -> None:
    data = sys.stdin.read().splitlines()
    t = int(data[0])
    out = []
    for i in range(1, t + 1):
        source, standard, optimization, warnings, output = parse_command(data[i])
        out.append(source)
        out.append(standard)
        out.append(optimization)
        out.append(" ".join(warnings) if warnings else "None")
        out.append(output)
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
