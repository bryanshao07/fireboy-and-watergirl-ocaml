# Fireboy & Watergirl — OCaml Edition

A two-player co-op puzzle-platformer built from scratch in OCaml, rendering
through the X11 `Graphics` library. Two players each control one character —
Fireboy and Watergirl — and must cooperate to collect gems and reach their
matching exits, while avoiding element-specific hazards: Fireboy dies in water,
Watergirl dies in fire, and both die in acid.

> Originally built as a CS 3110 (Functional Programming) final project.
> [Demo video](https://www.youtube.com/watch?v=doHxtFW-JR0)

![gameplay](docs/demo.gif)

## Highlights

- **Custom physics engine** — fixed-timestep gravity, friction, and jumping
  with swept tile-collision resolution that snaps players to tile edges and
  zeroes velocity on impact (`lib/physics.ml`).
- **From-scratch rendering** — nearest-neighbor sprite scaling, horizontal
  sprite flipping, and per-pixel RGBA alpha-compositing for the vignette
  overlay, all built on the bare `Graphics` image API (`lib/sprite.ml`,
  `lib/render.ml`).
- **Native two-player input** — a small C stub over X11's `XQueryKeymap`
  enables true simultaneous key polling for both players, which OCaml's
  `Graphics` event model can't do on its own (`lib/x11_input.c`,
  `lib/input.ml`). Jumps are edge-triggered (fire on key-down, not while held).
- **Pure, tested core** — game state is modeled as an explicit
  `Playing | Resetting | Won` state machine updated by a pure `tick` function.
  59 OUnit2 tests give **100% line coverage** on all game logic — collision,
  win/loss detection, gem collection, and state transitions — measured with
  `bisect_ppx`.

## Architecture

The code separates pure game logic from I/O (rendering and input), so the core
can be unit-tested without a display:

| Module        | Responsibility                                                   |
| ------------- | ---------------------------------------------------------------- |
| `level`       | Tile grid: parsing, bounds-checked queries, copying (pure)       |
| `player`      | Player state record and character types (pure)                   |
| `physics`     | Movement, gravity, and tile collision resolution (pure)          |
| `game`        | Top-level state machine and `tick` update loop (pure)            |
| `input`       | Keyboard sampling and edge-triggered "just pressed" detection    |
| `sprite`      | Image loading, scaling, flipping, and alpha-blending             |
| `render`      | All on-screen drawing: levels, players, HUD, intro/win screens   |
| `bin/main`    | The game loop wiring input → update → render together            |

Every module has an `.mli` interface documenting its public API.

## Controls

| Action  | Fireboy   | Watergirl |
| ------- | --------- | --------- |
| Move    | `J` / `L` | `A` / `D` |
| Jump    | `I`       | `W`       |

`Space` (or a jump key) advances the intro and restarts after a win ·
`R` restarts · `Q` quits.

## Setup

### macOS

1. Install XQuartz (required for the graphics library):
   - Download and run the `.pkg` from https://www.xquartz.org
   - Log out and back in after installing
2. Install the graphics and image libraries:
   ```
   opam install graphics camlimages
   ```
3. Build and run:
   ```
   dune exec bin/main.exe
   ```

### Windows (WSL)

1. Enable WSLg (Windows 11) or install VcXsrv (Windows 10):
   - **Windows 11**: WSLg is built in, no extra steps needed
   - **Windows 10**: Download and run [VcXsrv](https://sourceforge.net/projects/vcxsrv/), then add this to your `~/.bashrc`:
     ```
     export DISPLAY=:0
     ```
2. Install the graphics and image libraries inside WSL:
   ```
   sudo apt install libx11-dev
   opam install graphics camlimages
   ```
3. Build and run:
   ```
   dune exec bin/main.exe
   ```

## Tests

Run the OUnit2 suite:

```
dune test
```

Generate the line-coverage report (requires `bisect_ppx`):

```
dune test --instrument-with bisect_ppx --force
bisect-ppx-report summary
```

## Authors

Aayan Hussain (ah2425) · Bryan Shao (bs887) · Nhat Minh / Kevin (nt428)
