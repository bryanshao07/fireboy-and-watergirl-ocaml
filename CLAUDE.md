# CLAUDE.md — Fireboy and Watergirl (OCaml Edition)

## Project Overview

A 2-player Fireboy and Watergirl game implemented in OCaml using the `graphics` library.
Originally a Cornell CS 3110 team project, now extended independently as a portfolio project.

## Repo Structure

- `bin/` — entry point (main.ml)
- `lib/` — core game logic (players, levels, collision, rendering)
- `test/` — OUnit2 test suite
- `tools/` — Python utilities (level_editor.py)
- `levels/` — JSON level definition files
- `.github/workflows/` — GitHub Actions CI

## Build & Run

```bash
# Build
opam exec -- dune build

# Run the game
opam exec -- dune exec bin/main.exe

# Run tests
opam exec -- dune test
```

## Dependencies

- OCaml 5.0
- graphics (opam)
- yojson (opam) — for JSON level loading
- ounit2 (opam) — for tests

## Architecture Notes

- Levels are data-driven: defined in `levels/*.json` and parsed at runtime via `lib/level_loader.ml`
- Do not hardcode level layout in OCaml — edit the JSON files instead
- `lib/level_loader.mli` defines the public interface; keep implementation details out of the signature

## Testing

- Tests live in `test/`
- Focus on pure functions: collision detection, state transitions, win/loss conditions
- Run `opam exec -- dune test` to execute the full suite
- Every new function with testable pure logic should have corresponding tests

## Resume/Portfolio Context

This is a portfolio project targeting SWE internship applications.
When suggesting improvements, prioritize:

1. Code clarity and OCaml best practices (.mli files, named constants, clean module boundaries)
2. Test coverage of pure logic
3. The data-driven level system (JSON + Python editor)
4. CI pipeline correctness

## What Not to Touch

- Do not change the JSON level schema without updating level_loader.ml and level_editor.py together
- Do not add external OCaml dependencies without updating the .opam file and ci.yml
- Do not break the existing graphics rendering pipeline — it depends on XQuartz/WSLg being available
