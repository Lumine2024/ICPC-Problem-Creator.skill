# {{PROBLEM_TITLE}}

This workspace is for internal interactive problem authoring, data generation, and local verification only.

## Run

```powershell
./scripts/run-all-tests.ps1 -Workspace "examples/{{PROBLEM_NAME}}"
```

## Notes

- `config.json` drives local compilation, generation, and judging.
- Generated data is recreated under `build/generated`.
- The local interactor is `src/checker/interactor.cpp`.
- `interactlib.py` is copied into the workspace for local interactive tooling.
