(** Load levels from JSON files (see [levels/*.json]).

    The JSON schema is:
    {[
      {
        "name":   string,
        "width":  int,
        "height": int,
        "legend": { "<char>": "<tile_name>", ... },
        "grid":   [ string, ... ]
      }
    ]}
    where each grid row is exactly [width] characters, there are exactly
    [height] rows, and every character in the grid appears as a single-character
    key in [legend] mapped to one of the known tile names:
    [empty], [wall], [platform], [fire_pool], [water_pool], [acid],
    [fire_door], [water_door], [gem_fire], [gem_water], [button],
    [spawn_fire], [spawn_water]. *)

(** [tile_of_name name] decodes a JSON tile name into a {!Level.tile}.
    Raises [Failure] on an unknown name. *)
val tile_of_name : string -> Level.tile

(** [load_string json] parses a level from a JSON string.
    Raises [Failure] with a human-readable message on invalid JSON or any
    schema/validation error (wrong dimensions, unknown tile name, grid
    characters missing from the legend, etc.). *)
val load_string : string -> Level.t

(** [load_file path] reads and parses a level JSON file at [path].
    Raises [Sys_error] if the file cannot be read, and [Failure] on invalid
    JSON or schema violations (see {!load_string}). *)
val load_file : string -> Level.t
