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

type t = {
  grid : tile array array;
  width : int;
  height : int;
}

let tile_size = 30
let width lvl = lvl.width
let height lvl = lvl.height

let get lvl x y =
  if x < 0 || y < 0 || x >= lvl.width || y >= lvl.height then Wall
  else lvl.grid.(y).(x)

let set lvl x y tile =
  if x >= 0 && y >= 0 && x < lvl.width && y < lvl.height then
    lvl.grid.(y).(x) <- tile

let copy lvl = { lvl with grid = Array.map Array.copy lvl.grid }

let is_solid = function
  | Walltop -> true
  | Wall -> true
  | _ -> false

let tile_of_char = function
  | ' ' -> Empty
  | '-' -> Walltop
  | '#' -> Wall
  | 'F' -> Fire
  | 'W' -> Water
  | 'A' -> Acid
  | 'E' -> ExitFire
  | 'Q' -> ExitWater
  | 'R' -> DiamondFire
  | 'B' -> DiamondWater
  | 'T' -> Button
  | '1' -> SpawnFire
  | '2' -> SpawnWater
  | _ -> failwith "Unknown tile character"

let from_string_list rows =
  let height = List.length rows in
  let width =
    match rows with
    | [] -> 0
    | r :: _ -> String.length r
  in
  let grid =
    rows
    |> List.map (fun row ->
        if String.length row <> width then
          failwith "All rows must have the same width";
        Array.init width (fun x -> tile_of_char row.[x]))
    |> Array.of_list
  in
  { grid; width; height }

let load_level path =
  let ic = open_in path in
  let lines = ref [] in
  (try
     while true do
       lines := input_line ic :: !lines
     done
   with End_of_file -> ());
  close_in ic;
  from_string_list (List.rev !lines)

let level_one = load_level "data/level1.txt"
