import json
import subprocess
import sys
import threading
from typing import Iterable

from interactlib import write


def pump(src: Iterable[str], dst_proc: subprocess.Popen[str]):
    try:
        for line in src:
            write(dst_proc, line.rstrip("\n"), quiet=True)
    except BrokenPipeError:
        pass
    finally:
        try:
            dst_proc.stdin.close()
        except Exception:
            pass


def main():
    contestant_cmd = json.loads(sys.argv[1])
    interactor_cmd = json.loads(sys.argv[2])
    working_dir = sys.argv[3]
    timeout = float(sys.argv[4])

    contestant = subprocess.Popen(
        contestant_cmd,
        cwd=working_dir,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    interactor = subprocess.Popen(
        interactor_cmd,
        cwd=working_dir,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    t1 = threading.Thread(target=pump, args=(contestant.stdout, interactor), daemon=True)
    t2 = threading.Thread(target=pump, args=(interactor.stdout, contestant), daemon=True)
    t1.start()
    t2.start()

    timed_out = False
    try:
        contestant.wait(timeout=timeout)
        interactor.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        for proc in (contestant, interactor):
            try:
                proc.kill()
            except Exception:
                pass
        contestant.wait()
        interactor.wait()

    t1.join(timeout=1.0)
    t2.join(timeout=1.0)

    result = {
        "contestantExitCode": contestant.returncode,
        "interactorExitCode": interactor.returncode,
        "contestantStderr": contestant.stderr.read(),
        "interactorStderr": interactor.stderr.read(),
        "timedOut": timed_out,
    }
    print(json.dumps(result))


if __name__ == "__main__":
    main()
