#!/usr/bin/env python3
"""Unit tests for tools/level_editor.py (stdlib `unittest`, no dependencies).

Run with:
    python3 tools/test_level_editor.py
    python3 -m unittest discover -s tools -p 'test_*.py'
"""

import contextlib
import io
import os
import re
import tempfile
import unittest

import level_editor as le

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
LEVELS = os.path.join(REPO, "levels")


class TileVocabularyTests(unittest.TestCase):
    def test_lookup_tables_are_consistent(self):
        # Every tile round-trips name -> char -> name.
        for name, char, *_ in le.TILES:
            self.assertEqual(le.CHAR_OF_NAME[name], char)
            self.assertEqual(le.NAME_OF_CHAR[char], name)
        # Chars are unique, so the grid encoding is unambiguous.
        chars = [char for _n, char, *_ in le.TILES]
        self.assertEqual(len(chars), len(set(chars)))

    def test_matches_ocaml_loader(self):
        """The Python tile names must match lib/level_loader.ml exactly, or a
        level saved here would fail to load in the game."""
        ml = os.path.join(REPO, "lib", "level_loader.ml")
        with open(ml, encoding="utf-8") as f:
            src = f.read()
        # Pull the "<name>" tokens from the `| "name" -> Level.X` arms.
        ocaml_names = set(re.findall(r'\|\s*"([a-z_]+)"\s*->\s*Level\.', src))
        self.assertEqual(ocaml_names, le.KNOWN_NAMES)


class RoundTripTests(unittest.TestCase):
    def test_to_dict_emits_full_canonical_legend(self):
        d = le.Level(3, 2, name="X").to_dict()
        self.assertEqual(d["legend"], {c: n for n, c, *_ in le.TILES})
        self.assertEqual(d["width"], 3)
        self.assertEqual(d["height"], 2)
        self.assertEqual(len(d["grid"]), 2)
        self.assertTrue(all(len(row) == 3 for row in d["grid"]))

    def test_dict_round_trip_is_identity(self):
        lvl = le.Level(4, 3, name="RT")
        lvl.grid[0][0] = "wall"
        lvl.grid[1][2] = "fire_pool"
        lvl.grid[2][3] = "spawn_water"
        back = le.Level.from_dict(lvl.to_dict())
        self.assertEqual(back.name, lvl.name)
        self.assertEqual((back.width, back.height), (lvl.width, lvl.height))
        self.assertEqual(back.grid, lvl.grid)

    def test_file_round_trip(self):
        lvl = le.Level(5, 2, name="File")
        lvl.grid[0][0] = "gem_fire"
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "lvl.json")
            le.save_level(lvl, path)
            again = le.load_level(path)
        self.assertEqual(again.as_text(), lvl.as_text())
        self.assertEqual(again.name, "File")

    def test_honors_foreign_legend_on_load(self):
        # A file may use any chars; from_dict must decode via its own legend.
        data = {
            "name": "Foreign",
            "width": 2,
            "height": 1,
            "legend": {"@": "wall", ".": "empty"},
            "grid": ["@."],
        }
        lvl = le.Level.from_dict(data)
        self.assertEqual(lvl.grid[0], ["wall", "empty"])
        # ...and re-saves using the canonical legend, not the foreign one.
        self.assertEqual(lvl.to_dict()["grid"], ["# "])


class ValidationTests(unittest.TestCase):
    def _from(self, **overrides):
        data = {
            "name": "x",
            "width": 2,
            "height": 1,
            "legend": {"#": "wall", " ": "empty"},
            "grid": ["# "],
        }
        data.update(overrides)
        return lambda: le.Level.from_dict(data)

    def test_missing_field(self):
        data = {"name": "x", "width": 1, "height": 1, "grid": ["#"]}  # no legend
        self.assertRaisesRegex(ValueError, "missing required field: 'legend'",
                               le.Level.from_dict, data)

    def test_multichar_legend_key(self):
        self.assertRaisesRegex(
            ValueError, "single character",
            self._from(legend={"##": "wall"}, grid=["##"], width=2))

    def test_unknown_tile_name(self):
        self.assertRaisesRegex(
            ValueError, "unknown tile name 'lava'",
            self._from(legend={"#": "lava", " ": "empty"}))

    def test_row_width_mismatch(self):
        self.assertRaisesRegex(
            ValueError, "has length 1 but width is 2", self._from(grid=["#"]))

    def test_row_count_mismatch(self):
        self.assertRaisesRegex(
            ValueError, "has 1 rows but height is 2", self._from(height=2))

    def test_char_not_in_legend(self):
        self.assertRaisesRegex(
            ValueError, r"character '\?' not defined in legend",
            self._from(grid=["#?"]))


class ShippedLevelTests(unittest.TestCase):
    def _load(self, name):
        return le.load_level(os.path.join(LEVELS, name))

    def test_level1_shape(self):
        lvl = self._load("level1.json")
        self.assertEqual((lvl.width, lvl.height), (28, 23))
        self._assert_required_entities(lvl)

    def test_level2_shape(self):
        lvl = self._load("level2.json")
        self.assertEqual((lvl.width, lvl.height), (22, 30))
        self._assert_required_entities(lvl)

    def _assert_required_entities(self, lvl):
        flat = [t for row in lvl.grid for t in row]
        for required in ("spawn_fire", "spawn_water", "fire_door", "water_door"):
            self.assertEqual(
                flat.count(required), 1,
                f"expected exactly one {required}")

    def test_shipped_levels_round_trip(self):
        for name in ("level1.json", "level2.json"):
            lvl = self._load(name)
            self.assertEqual(
                le.Level.from_dict(lvl.to_dict()).as_text(), lvl.as_text())


class HeadlessCommandTests(unittest.TestCase):
    def test_new_writes_loadable_blank_level(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "blank.json")
            with contextlib.redirect_stdout(io.StringIO()):
                le.cmd_new(6, 4, path)
            lvl = le.load_level(path)
            self.assertEqual((lvl.width, lvl.height), (6, 4))
            self.assertTrue(all(t == "empty" for row in lvl.grid for t in row))


if __name__ == "__main__":
    unittest.main(verbosity=2)
