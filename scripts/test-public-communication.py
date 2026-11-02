"""Exercise a workspace's standalone contestant tester using external fixtures."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', type=Path, required=True)
    args = parser.parse_args()
    workspace = args.workspace.resolve()
    repository = Path(__file__).resolve().parents[1]
    config = json.loads((workspace / 'config.json').read_text(encoding='utf-8'))
    suite = json.loads((workspace / config['localTester']['tests']).read_text(encoding='utf-8'))
    build = repository / '.codex-test-artifacts/build' / config['slug']
    extension = '.exe' if os.name == 'nt' else ''
    programs = {}
    for entry in config['solutions'] + config['wrongSolutions']:
        programs[entry['name']] = ([str(build / 'bin' / (entry['name'] + extension))]
                                   if entry['language'] == 'cpp'
                                   else [sys.executable, str(workspace / entry['path'])])
    artifact_parent = repository / '.codex-test-artifacts/public-checker'
    artifact_parent.mkdir(parents=True, exist_ok=True)
    # A space in the build directory deliberately exercises argv/path handling.
    root = Path(tempfile.mkdtemp(prefix='audit ', dir=artifact_parent))
    fixture = root / ('fixture' + extension)
    flags = [flag.replace('{{standard}}', config['standard']) for flag in config['build']['cppFlags']]
    compiler = shutil.which(config['build']['cppCompiler'])
    subprocess.run([compiler, *flags, '-I', str(workspace / 'include'),
                    str(workspace / suite['fixture']), '-o', str(fixture)], check=True)
    programs['fixture'] = [str(fixture)]
    copied = root / 'standalone'
    copied.mkdir()
    for name in config['publicAttachments']:
        shutil.copy2(workspace / name, copied / Path(name).name)
    checker = copied / Path(config['localTester']['path']).name
    reports = []
    for test in suite['cases']:
        relative_input = suite['inputs'][test['input']]
        input_file = (build / 'generated' / relative_input[len('@generated/'):]
                      if relative_input.startswith('@generated/') else workspace / relative_input)
        command = [sys.executable, str(checker), '--input', str(input_file)]
        if 'timeout' in test:
            command += ['--timeout', str(test['timeout'])]
        command += test.get('options', [])
        log_parent = root / test['name']
        if test.get('logs'):
            command += ['--log-dir', str(log_parent)]
        command += programs[test['program']] + test.get('arguments', [])
        result = subprocess.run(command, cwd=copied, capture_output=True, text=True, timeout=30)
        diagnostic = result.stdout + result.stderr
        if result.returncode != test['exit'] or test['contains'] not in diagnostic or 'Traceback' in diagnostic:
            raise AssertionError(f"{test['name']}: exit={result.returncode}, expected={test['exit']}\n{diagnostic}")
        if test.get('logs'):
            run_directory, = log_parent.iterdir()
            assert (run_directory / 'alice.in').exists()
            assert (run_directory / 'alice.out').exists()
            assert (run_directory / 'bob.in').exists() == test['bobStarted']
            for actual, expected in test.get('expectedFiles', {}).items():
                assert (run_directory / actual).read_bytes().split() == (workspace / expected).read_bytes().split(), actual
        reports.append({'name': test['name'], 'exit': result.returncode})
        print(f"[test] {test['name']}: OK", flush=True)
    # Compile with the user's exact minimal g++ argument pattern, then run using
    # just the public files and relative paths from an unrelated directory.
    source = copied / (config['slug'] + '.cpp')
    source.write_bytes((workspace / config['solutions'][0]['path']).read_bytes())
    executable = copied / (config['slug'] + extension)
    subprocess.run([compiler, source.name, '-o', executable.name], cwd=copied, check=True)
    result = subprocess.run([sys.executable, checker.name, '--input',
                             Path(config['localTester']['exampleInput']).name,
                             './' + executable.name], cwd=copied, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    reports.append({'name': 'standalone-exact-command', 'exit': result.returncode})
    (root / 'report.json').write_text(json.dumps(reports, indent=2) + '\n', encoding='utf-8')
    print(f'[success] standalone tester passed {len(reports)} tests; report={root / "report.json"}')


if __name__ == '__main__':
    main()
