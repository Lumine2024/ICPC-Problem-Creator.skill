# {{PROBLEM_TITLE}}

This workspace is for internal problem authoring, data generation, and local verification only. It is not intended for target OJ submission workflows.

## Run

```powershell
./scripts/run-all-tests.ps1 -Workspace "examples/{{PROBLEM_NAME}}"
```

## `config.json`

Important fields:

- `slug`, `title`: human-readable identifiers for the workspace.
- `interactive`: selects checker mode or interactor mode.
- `timeLimitMs`, `memoryLimitMb`: runtime metadata used by local validation.
- `statement`, `tutorial`: documentation entry points.
- `validator`: strict input validator.
- `generator.path`, `generator.cases`: reproducible data generation plan.
- `checker` or `interactor`: local judging logic.
- `solutions`: main and reference implementations.
- `wrongSolutions`: deliberately incorrect solutions that must fail on generated data.

## Notes

Generated test files live under `build/generated` and do not need to be committed.
