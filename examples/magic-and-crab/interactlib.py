import sys
from subprocess import *

__all__ = ["write", "read", "wrong"]


def write(p: Popen[str], line, /, quiet=False):
    assert p.poll() is None and p.stdin is not None
    if not quiet:
        print(f"Write: {line}", flush=True)
    p.stdin.write(f"{line}\n")
    p.stdin.flush()


def read(p: Popen[str], /, quiet=False):
    assert p.poll() is None and p.stdout is not None
    line = p.stdout.readline().strip()
    assert line != ""
    if not quiet:
        print(f"Read: {line}", flush=True)
    return line


def wrong(p: Popen[str], msg):
    p.kill()
    print(f"Wrong answer: {msg}")
    sys.exit(1)
