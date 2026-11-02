"""First invocation of Polygon run-twice: wire submission <-> testlib interactor.

All commands, paths and limits come from the JSON manifest argument. The interactor
writes the second invocation input to its testlib `tout` file, not to this broker.
This is a trusted local runner, not an operating-system sandbox.
"""
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time


def memory_bytes(proc):
    if proc.poll() is not None:
        return 0
    try:
        if os.name == "nt":
            from ctypes import wintypes

            class Counters(ctypes.Structure):
                _fields_ = [("cb", wintypes.DWORD), ("faults", wintypes.DWORD)] + [
                    (name, ctypes.c_size_t) for name in (
                        "peak_rss", "rss", "peak_paged", "paged", "peak_nonpaged",
                        "nonpaged", "private", "peak_private")]

            counters = Counters()
            counters.cb = ctypes.sizeof(counters)
            if not ctypes.windll.psapi.GetProcessMemoryInfo(
                    wintypes.HANDLE(int(proc._handle)), ctypes.byref(counters), counters.cb):
                raise OSError("GetProcessMemoryInfo failed")
            return max(counters.rss, counters.private)
        status = Path(f"/proc/{proc.pid}/status")
        if status.exists():
            values = {}
            for line in status.read_text().splitlines():
                if line.startswith(("VmRSS:", "VmData:")):
                    key, value, _ = line.split()
                    values[key] = int(value) * 1024
            return max(values.values(), default=0)
        if proc.poll() is not None:
            return 0
        rss = subprocess.check_output(["ps", "-o", "rss=", "-p", str(proc.pid)])
        return int(rss.strip() or b"0") * 1024
    except (OSError, ValueError, subprocess.SubprocessError):
        if proc.poll() is not None:
            return 0
        raise


def terminate(proc):
    if proc is not None and proc.poll() is None:
        proc.kill()


def judge_verdict(exit_code):
    return {0: 'AC', 1: 'WA', 2: 'PE', 3: 'FAIL', 4: 'WA', 8: 'PE'}.get(exit_code, 'FAIL')


def pump(source, destination, log_path, errors):
    try:
        with open(log_path, "wb") as log:
            while True:
                chunk = os.read(source.fileno(), 65536)
                if not chunk:
                    break
                log.write(chunk)
                destination.write(chunk)
                destination.flush()
    except (BrokenPipeError, OSError):
        # An early verdict/exit is handled by the supervisor, not by a pipe thread.
        pass
    except Exception as exc:
        errors.append(repr(exc))
    finally:
        # Closing the read end also releases a sender when its peer exits without
        # consuming the remaining input. Do not leave an unread pipe open.
        try:
            source.close()
        except OSError:
            pass
        try:
            destination.close()
        except OSError:
            pass


def run(spec):
    root = Path(spec["artifactPath"])
    contestant = interactor = None
    threads = []
    errors = []
    result = {"verdict": "AC", "contestantExitCode": None,
              "interactorExitCode": None, "diagnostic": ""}
    try:
        with open(root / "alice.stderr", "wb") as alice_err, open(root / "interactor.stderr", "wb") as judge_err:
            environment = os.environ.copy()
            environment.update({key: spec["contestantDirectory"] for key in ("TEMP", "TMP", "TMPDIR")})
            contestant = subprocess.Popen(spec["contestantCommand"], cwd=spec["contestantDirectory"],
                                          env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                          stderr=alice_err)
            started = time.monotonic()
            interactor = subprocess.Popen(spec["interactorCommand"], cwd=spec["interactorDirectory"],
                                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=judge_err)
            threads = [
                threading.Thread(target=pump, args=(contestant.stdout, interactor.stdin,
                                                   root / "alice.out", errors), daemon=True),
                threading.Thread(target=pump, args=(interactor.stdout, contestant.stdin,
                                                   root / "alice.in", errors), daemon=True),
            ]
            for thread in threads:
                thread.start()
            deadline = started + spec["timeoutMs"] / 1000
            judge_deadline = deadline + spec["judgeGraceMs"] / 1000
            while True:
                alice_code, judge_code = contestant.poll(), interactor.poll()
                if alice_code is not None and judge_code is not None:
                    break
                if judge_code is not None and judge_code != 0:
                    result["verdict"] = judge_verdict(judge_code)
                    break
                if alice_code is not None and alice_code != 0:
                    result["verdict"] = "RE"
                    break
                if alice_code is None and memory_bytes(contestant) > spec["memoryLimitMb"] * 1024 * 1024:
                    result["verdict"] = "MLE"
                    break
                if alice_code is None and time.monotonic() > deadline:
                    result["verdict"] = "TLE"
                    break
                if time.monotonic() > judge_deadline:
                    result["verdict"] = "FAIL"
                    result["diagnostic"] = "interactor did not terminate after the first invocation"
                    break
                time.sleep(0.01)
            if result["verdict"] != "AC":
                terminate(contestant)
                terminate(interactor)
            contestant.wait()
            interactor.wait()
            for thread in threads:
                thread.join(timeout=1)
            if errors:
                raise RuntimeError("pipe broker: " + "; ".join(errors))
            result["contestantExitCode"] = contestant.returncode
            result["interactorExitCode"] = interactor.returncode
            if result["verdict"] == "AC":
                if interactor.returncode != 0:
                    result["verdict"] = judge_verdict(interactor.returncode)
                elif contestant.returncode != 0:
                    result["verdict"] = "RE"
    finally:
        terminate(contestant)
        terminate(interactor)
        for proc in (contestant, interactor):
            if proc is not None:
                proc.wait()
    result["contestantStderr"] = (root / "alice.stderr").read_text(encoding="utf-8", errors="replace")
    result["interactorStderr"] = (root / "interactor.stderr").read_text(encoding="utf-8", errors="replace")
    return result


if __name__ == "__main__":
    manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    print(json.dumps(run(manifest), ensure_ascii=True))
