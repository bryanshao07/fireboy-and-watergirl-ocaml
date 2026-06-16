(** Level grids: the static layout of tiles. *)

(** A single tile in the level grid. *)
type tile =
  | Empty
  | Wall
  | Walltop
  | Fire
  | Water
  | Acid
  | ExitFire
  | ExitWater
  | DiamondFire
  | DiamondWater
  | Button
  | SpawnFire
  | SpawnWater

(** A 2D grid of tiles plus its dimensions. *)
type t = {
  grid : tile array array;
  width : int;
  height : int;
}

(** Side length of one tile, in world pixels. The single source of truth for
    this constant, shared by physics, game logic, and rendering. *)
val tile_size : int

(** Number of columns. *)
val width : t -> int

(** Number of rows. *)
val height : t -> int

(** [get lvl x y] is the tile at column [x], row [y].
    Out-of-bounds coordinates return [Wall]. *)
val get : t -> int -> int -> tile

(** [set lvl x y tile] mutates [lvl] at column [x], row [y].
    Out-of-bounds coordinates are ignored. *)
val set : t -> int -> int -> tile -> unit

(** Deep copy of the level. *)
val copy : t -> t

(** [true] iff a player cannot pass through this tile. *)
val is_solid : tile -> bool

(** Decode one character of a level string into a tile.
    Raises [Failure] on unknown characters. *)
val tile_of_char : char -> tile

(** Build a level from a list of equal-length rows.
    Raises [Failure] on inconsistent widths or unknown characters. *)
val from_string_list : string list -> t

(** [load_level path] reads a level from a plain-text file whose lines use
    the tile character encoding. Raises [Sys_error] if the file is missing,
    [Failure] on inconsistent row widths or unknown characters. *)
val load_level : string -> t

(** Level one, loaded from [data/level1.txt] at program start. *)
val level_one : t