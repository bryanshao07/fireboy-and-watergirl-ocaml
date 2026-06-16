#!/usr/bin/env python3
"""Level editor for the OCaml Fireboy & Watergirl game.

Reads and writes the JSON level format consumed by `lib/level_loader.ml`:

    {
      "name":   str,
      "width":  int,
      "height": int,
      "legend": { "<char>": "<tile_name>", ... },
      "grid":   [ "<row string>", ... ]   # height rows, each width chars
    }

Usage:
    python tools/level_editor.py [path.json]        # open the tkinter GUI
    python tools/level_editor.py --text [path.json] # terminal (curses) editor
    python tools/level_editor.py --show f.json      # print a level to the terminal
    python tools/level_editor.py --new W H out.json # write a blank level

Only the Python standard library is used (json, argparse, tkinter, curses).
The --text editor needs no GUI toolkit, so it works where tkinter is broken
(e.g. an Anaconda Tk that aborts on recent macOS).
"""

from __future__ import annotations

import argparse
import json
import sys

# --------------------------------------------------------------------------
# Tile vocabulary -- must stay in sync with lib/level_loader.ml.
# Each entry: tile name, canonical legend char, fill color, outline/text color.
# --------------------------------------------------------------------------
TILES = [
    ("empty",       " ", "#ffffff", "#cccccc"),
    ("wall",        "#", "#202020", "#202020"),
    ("platform",    "-", "#8a5a2b", "#5a3a1b"),
    ("fire_pool",   "F", "#e23b1e", "#a01000"),
    ("water_pool",  "W", "#2b6fe2", "#1040a0"),
    ("acid",        "A", "#3bbf3b", "#1a7a1a"),
    ("fire_door",   "E", "#ff9696", "#c04040"),
    ("water_door",  "Q", "#9696ff", "#4040c0"),
    ("gem_fire",    "R", "#ff5050", "#900000"),
    ("gem_water",   "B", "#5050ff", "#000090"),
    ("button",      "T", "#f2d12b", "#a08000"),
    ("spawn_fire",  "1", "#ffb4b4", "#c06060"),
    ("spawn_water", "2", "#b4b4ff", "#6060c0"),
]

NAME_OF_CHAR = {char: name for name, char, *_ in TILES}
CHAR_OF_NAME = {name: char for name, char, *_ in TILES}
FILL_OF_NAME = {name: fill for name, _c, fill, _o in TILES}
KNOWN_NAMES = set(CHAR_OF_NAME)

DEFAULT_W, DEFAULT_H = 28, 23


class Level:
    """A grid of tile names with a name and dimensions."""

    def __init__(self, width, height, name="Untitled", grid=None):
        self.name = name
        self.width = width
        self.height = height
        if grid is None:
            grid = [["empty"] * width for _ in range(height)]
        self.grid = grid

    # ---- serialization ---------------------------------------------------
    @classmethod
    def from_dict(cls, data):
        """Build a Level from parsed JSON, honoring the file's own legend."""
        for key in ("name", "width", "height", "legend", "grid"):
            if key not in data:
                raise ValueError(f"missing required field: {key!r}")
        width, height = int(data["width"]), int(data["height"])
        legend = data["legend"]
        for ch, tilename in legend.items():
            if len(ch) != 1:
                raise ValueError(f"legend key {ch!r} must be a single character")
            if tilename not in KNOWN_NAMES:
                raise ValueError(f"unknown tile name {tilename!r} in legend")
        rows = data["grid"]
        if len(rows) != height:
            raise ValueError(f"grid has {len(rows)} rows but height is {height}")
        grid = []
        for row in rows:
            if len(row) != width:
                raise ValueError(
                    f"row {row!r} has length {len(row)} but width is {width}"
                )
            decoded = []
            for ch in row:
                if ch not in legend:
                    raise ValueError(f"character {ch!r} not defined in legend")
                decoded.append(legend[ch])
            grid.append(decoded)
        return cls(width, height, name=data["name"], grid=grid)

    def to_dict(self):
        """Serialize to the JSON schema, emitting the full canonical legend."""
        rows = ["".join(CHAR_OF_NAME[name] for name in row) for row in self.grid]
        return {
            "name": self.name,
            "width": self.width,
            "height": self.height,
            "legend": {char: name for name, char, *_ in TILES},
            "grid": rows,
        }

    def as_text(self):
        """Human-readable grid using the canonical chars (for --show)."""
        rows = ["".join(CHAR_OF_NAME[name] for name in row) for row in self.grid]
        return "\n".join(rows)


def load_level(path):
    with open(path, "r", encoding="utf-8") as f:
        return Level.from_dict(json.load(f))


def save_level(level, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(level.to_dict(), f, indent=2)
        f.write("\n")


# --------------------------------------------------------------------------
# Headless helpers
# --------------------------------------------------------------------------
def cmd_show(path):
    level = load_level(path)
    print(f"{level.name}  ({level.width}x{level.height})")
    print(level.as_text())


def cmd_new(width, height, path):
    save_level(Level(width, height, name=f"Level {width}x{height}"), path)
    print(f"wrote blank {width}x{height} level to {path}")


# --------------------------------------------------------------------------
# tkinter GUI
# --------------------------------------------------------------------------
def run_gui(initial_path=None):
    import tkinter as tk
    from tkinter import filedialog, messagebox, simpledialog

    CELL = 24  # pixels per tile

    class Editor:
        def __init__(self, root):
            self.root = root
            self.root.title("Fireboy & Watergirl — Level Editor")
            self.level = Level(DEFAULT_W, DEFAULT_H, name="Level 1")
            self.path = None
            self.current = "wall"
            self._build_toolbar()
            self._build_palette()
            self._build_canvas()
            if initial_path:
                self._load_path(initial_path)
            else:
                self._redraw()

        # ---- layout ------------------------------------------------------
        def _build_toolbar(self):
            bar = tk.Frame(self.root)
            bar.pack(side=tk.TOP, fill=tk.X, padx=4, pady=4)
            tk.Button(bar, text="New", command=self.on_new).pack(side=tk.LEFT)
            tk.Button(bar, text="Load JSON", command=self.on_load).pack(side=tk.LEFT)
            tk.Button(bar, text="Save JSON", command=self.on_save).pack(side=tk.LEFT)
            tk.Button(bar, text="Save As…", command=self.on_save_as).pack(side=tk.LEFT)
            self.status = tk.Label(bar, text="", anchor="e")
            self.status.pack(side=tk.RIGHT)

        def _build_palette(self):
            pal = tk.Frame(self.root)
            pal.pack(side=tk.LEFT, fill=tk.Y, padx=4, pady=4)
            tk.Label(pal, text="Tiles").pack(anchor="w")
            self.pal_buttons = {}
            for name, char, fill, outline in TILES:
                b = tk.Button(
                    pal,
                    text=f"{name}  '{char}'",
                    anchor="w",
                    bg=fill,
                    fg=outline if name != "empty" else "#666666",
                    activebackground=fill,
                    relief=tk.RAISED,
                    command=lambda n=name: self.select(n),
                )
                b.pack(fill=tk.X, pady=1)
                self.pal_buttons[name] = b
            self.select(self.current)

        def _build_canvas(self):
            frame = tk.Frame(self.root)
            frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=4, pady=4)
            self.canvas = tk.Canvas(frame, background="#dddddd")
            self.canvas.pack(fill=tk.BOTH, expand=True)
            self.canvas.bind("<Button-1>", self.on_paint)
            self.canvas.bind("<B1-Motion>", self.on_paint)
            self.canvas.bind("<Button-3>", self.on_erase)
            self.canvas.bind("<B3-Motion>", self.on_erase)

        # ---- interaction -------------------------------------------------
        def select(self, name):
            self.current = name
            for n, b in self.pal_buttons.items():
                b.config(relief=tk.SUNKEN if n == name else tk.RAISED)
            self._set_status()

        def _cell_at(self, event):
            x, y = event.x // CELL, event.y // CELL
            if 0 <= x < self.level.width and 0 <= y < self.level.height:
                return x, y
            return None

        def on_paint(self, event):
            self._place(event, self.current)

        def on_erase(self, event):
            self._place(event, "empty")

        def _place(self, event, name):
            cell = self._cell_at(event)
            if cell is None:
                return
            x, y = cell
            if self.level.grid[y][x] != name:
                self.level.grid[y][x] = name
                self._draw_cell(x, y)

        # ---- file actions ------------------------------------------------
        def on_new(self):
            dims = simpledialog.askstring(
                "New level", "width height (e.g. 28 23):", parent=self.root
            )
            if not dims:
                return
            try:
                w, h = (int(v) for v in dims.split())
                if w <= 0 or h <= 0:
                    raise ValueError
            except ValueError:
                messagebox.showerror("New level", "Enter two positive integers.")
                return
            self.level = Level(w, h, name="Untitled")
            self.path = None
            self._redraw()

        def on_load(self):
            path = filedialog.askopenfilename(
                filetypes=[("JSON levels", "*.json"), ("All files", "*")]
            )
            if path:
                self._load_path(path)

        def _load_path(self, path):
            try:
                self.level = load_level(path)
            except (ValueError, json.JSONDecodeError, OSError) as exc:
                messagebox.showerror("Load failed", str(exc))
                return
            self.path = path
            self._redraw()

        def on_save(self):
            if self.path is None:
                self.on_save_as()
            else:
                self._save_path(self.path)

        def on_save_as(self):
            path = filedialog.asksaveasfilename(
                defaultextension=".json",
                filetypes=[("JSON levels", "*.json"), ("All files", "*")],
            )
            if path:
                self._save_path(path)

        def _save_path(self, path):
            name = simpledialog.askstring(
                "Level name", "Name:", initialvalue=self.level.name,
                parent=self.root,
            )
            if name:
                self.level.name = name
            try:
                save_level(self.level, path)
            except OSError as exc:
                messagebox.showerror("Save failed", str(exc))
                return
            self.path = path
            self._set_status()

        # ---- rendering ---------------------------------------------------
        def _redraw(self):
            self.canvas.config(
                width=self.level.width * CELL, height=self.level.height * CELL
            )
            self.canvas.delete("all")
            for y in range(self.level.height):
                for x in range(self.level.width):
                    self._draw_cell(x, y)
            self._set_status()

        def _draw_cell(self, x, y):
            name = self.level.grid[y][x]
            x0, y0 = x * CELL, y * CELL
            tag = f"c{x}_{y}"
            self.canvas.delete(tag)
            self.canvas.create_rectangle(
                x0, y0, x0 + CELL, y0 + CELL,
                fill=FILL_OF_NAME[name], outline="#bbbbbb", tags=tag,
            )
            if name != "empty":
                self.canvas.create_text(
                    x0 + CELL / 2, y0 + CELL / 2,
                    text=CHAR_OF_NAME[name], tags=tag,
                )

        def _set_status(self):
            where = self.path or "(unsaved)"
            self.status.config(
                text=f"{self.level.name}  {self.level.width}x{self.level.height}"
                f"  paint: {self.current}  —  {where}"
            )

    root = tk.Tk()
    Editor(root)
    root.mainloop()


# --------------------------------------------------------------------------
# Terminal (curses) editor -- no GUI toolkit required
# --------------------------------------------------------------------------
def run_text(initial_path=None):
    """A curses grid editor. Uses only the stdlib `curses` module."""
    import curses

    def editor(stdscr):
        curses.curs_set(0)
        stdscr.keypad(True)

        if initial_path:
            level = load_level(initial_path)
            path = initial_path
        else:
            level = Level(28, 23, name="Untitled")
            path = None

        cx = cy = 0          # cursor cell
        vx = vy = 0          # viewport top-left (for grids bigger than screen)
        brush = "wall"
        msg = "arrows/hjkl move  tile-key paints  space=brush  x=erase  :=command"

        def prompt(prefix):
            """Read a line at the bottom of the screen (Esc cancels)."""
            curses.curs_set(1)
            buf = ""
            maxy, maxx = stdscr.getmaxyx()
            while True:
                stdscr.move(maxy - 1, 0)
                stdscr.clrtoeol()
                stdscr.addnstr(maxy - 1, 0, (prefix + buf)[: maxx - 1], maxx - 1)
                ch = stdscr.get_wch()
                if ch in ("\n", "\r"):
                    curses.curs_set(0)
                    return buf
                if ch == "\x1b":  # Esc
                    curses.curs_set(0)
                    return None
                if ch in ("\x7f", "\b") or ch == curses.KEY_BACKSPACE:
                    buf = buf[:-1]
                elif isinstance(ch, str) and ch.isprintable():
                    buf += ch

        def run_command(line):
            """Execute a ':' command. Returns False to quit the editor."""
            nonlocal path, level, msg, cx, cy, vx, vy
            parts = line.split()
            if not parts:
                return True
            cmd, rest = parts[0], parts[1:]
            if cmd in ("w", "wq"):
                target = rest[0] if rest else path
                if not target:
                    msg = "no filename: use ':w <path>'"
                    return True
                save_level(level, target)
                path = target
                msg = f"wrote {target}"
                return cmd != "wq"
            if cmd in ("q", "q!"):
                return False
            if cmd == "name":
                level.name = " ".join(rest) or level.name
                msg = f"name = {level.name}"
            elif cmd == "new":
                try:
                    w, h = int(rest[0]), int(rest[1])
                    level = Level(w, h, name=level.name)
                    cx = cy = vx = vy = 0
                    msg = f"new {w}x{h}"
                except (IndexError, ValueError):
                    msg = "usage: :new W H"
            else:
                msg = f"unknown command: {cmd}"
            return True

        def draw(s, y, x, text, attr=curses.A_NORMAL):
            try:
                stdscr.addnstr(y, x, text, max(0, len(text)), attr)
            except curses.error:
                pass

        running = True
        while running:
            stdscr.erase()
            maxy, maxx = stdscr.getmaxyx()
            view_h = max(1, maxy - 3)
            view_w = max(1, min(level.width, maxx - 1))

            cx = max(0, min(cx, level.width - 1))
            cy = max(0, min(cy, level.height - 1))
            if cy < vy:
                vy = cy
            elif cy >= vy + view_h:
                vy = cy - view_h + 1
            if cx < vx:
                vx = cx
            elif cx >= vx + view_w:
                vx = cx - view_w + 1

            here = level.grid[cy][cx]
            status = (
                f" {level.name}  {level.width}x{level.height}  "
                f"({cx},{cy})={here}  brush={brush} "
            )
            draw(stdscr, 0, 0, status.ljust(maxx - 1)[: maxx - 1], curses.A_REVERSE)

            for sy in range(view_h):
                gy = vy + sy
                if gy >= level.height:
                    break
                for sx in range(view_w):
                    gx = vx + sx
                    if gx >= level.width:
                        break
                    char = CHAR_OF_NAME[level.grid[gy][gx]]
                    disp = char if char != " " else "."
                    attr = (
                        curses.A_REVERSE
                        if (gx == cx and gy == cy)
                        else curses.A_NORMAL
                    )
                    draw(stdscr, 1 + sy, sx, disp, attr)

            draw(stdscr, maxy - 2, 0, msg[: maxx - 1])
            legend = "keys: " + "  ".join(
                f"{c}={n}" for n, c, *_ in TILES if c != " "
            )
            draw(stdscr, maxy - 1, 0, legend[: maxx - 1])
            stdscr.refresh()

            ch = stdscr.get_wch()
            if ch in (curses.KEY_UP, "k"):
                cy -= 1
            elif ch in (curses.KEY_DOWN, "j"):
                cy += 1
            elif ch in (curses.KEY_LEFT, "h"):
                cx -= 1
            elif ch in (curses.KEY_RIGHT, "l"):
                cx += 1
            elif ch == " ":
                level.grid[cy][cx] = brush
            elif ch == "x":
                level.grid[cy][cx] = "empty"
            elif ch == ":":
                line = prompt(":")
                if line is not None:
                    running = run_command(line)
            elif isinstance(ch, str) and ch in NAME_OF_CHAR and ch != " ":
                brush = NAME_OF_CHAR[ch]
                level.grid[cy][cx] = brush

    curses.wrapper(editor)


# --------------------------------------------------------------------------
def main(argv=None):
    parser = argparse.ArgumentParser(description="Fireboy & Watergirl level editor")
    parser.add_argument("path", nargs="?", help="JSON level to open in an editor")
    parser.add_argument(
        "--text", action="store_true",
        help="use the terminal (curses) editor instead of the tkinter GUI",
    )
    parser.add_argument("--show", metavar="FILE", help="print a level and exit")
    parser.add_argument(
        "--new", nargs=3, metavar=("W", "H", "OUT"),
        help="write a blank WxH level to OUT and exit",
    )
    args = parser.parse_args(argv)

    if args.show:
        cmd_show(args.show)
        return
    if args.new:
        w, h, out = args.new
        cmd_new(int(w), int(h), out)
        return
    if args.text:
        try:
            run_text(args.path)
        except Exception as exc:  # not a real terminal / curses unavailable
            print(f"terminal editor unavailable ({exc}).", file=sys.stderr)
            sys.exit(1)
        return
    try:
        run_gui(args.path)
    except Exception as exc:  # tkinter unavailable / no display
        print(f"GUI unavailable ({exc}).", file=sys.stderr)
        print("Use --show FILE or --new W H OUT for headless operation.",
              file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
