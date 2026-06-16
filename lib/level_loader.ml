open Yojson.Safe.Util

let tile_of_name = function
  | "empty" -> Level.Empty
  | "wall" -> Level.Wall
  | "platform" -> Level.Walltop
  | "fire_pool" -> Level.Fire
  | "water_pool" -> Level.Water
  | "acid" -> Level.Acid
  | "fire_door" -> Level.ExitFire
  | "water_door" -> Level.ExitWater
  | "gem_fire" -> Level.DiamondFire
  | "gem_water" -> Level.DiamondWater
  | "button" -> Level.Button
  | "spawn_fire" -> Level.SpawnFire
  | "spawn_water" -> Level.SpawnWater
  | other -> failwith (Printf.sprintf "Unknown tile name %S in legend" other)

(* Build a char -> tile lookup table from the JSON "legend" object. *)
let parse_legend json =
  let legend = Hashtbl.create 32 in
  json |> member "legend" |> to_assoc
  |> List.iter (fun (key, value) ->
         if String.length key <> 1 then
           failwith
             (Printf.sprintf "Legend key %S must be a single character" key);
         Hashtbl.replace legend key.[0] (tile_of_name (to_string value)));
  legend

let parse json =
  let name = json |> member "name" |> to_string in
  ignore (name : string);
  let width = json |> member "width" |> to_int in
  let height = json |> member "height" |> to_int in
  if width < 0 || height < 0 then
    failwith "Level width and height must be non-negative";
  let legend = parse_legend json in
  let rows = json |> member "grid" |> to_list |> List.map to_string in
  if List.length rows <> height then
    failwith
      (Printf.sprintf "grid has %d rows but height is %d" (List.length rows)
         height);
  let grid =
    rows
    |> List.map (fun row ->
           if String.length row <> width then
             failwith
               (Printf.sprintf "grid row %S has length %d but width is %d" row
                  (String.length row) width);
           Array.init width (fun x ->
               let c = row.[x] in
               match Hashtbl.find_opt legend c with
               | Some tile -> tile
               | None ->
                   failwith
                     (Printf.sprintf
                        "grid character %C is not defined in the legend" c)))
    |> Array.of_list
  in
  { Level.grid; width; height }

(* Translate Yojson's structural exceptions into [Failure] so callers only
   have to handle one error type, matching [Level.load_level]. *)
let with_clear_errors f =
  try f () with
  | Type_error (msg, _) -> failwith ("level JSON: " ^ msg)
  | Yojson.Json_error msg -> failwith ("invalid level JSON: " ^ msg)

let load_string s =
  with_clear_errors (fun () -> parse (Yojson.Safe.from_string s))

let load_file path =
  with_clear_errors (fun () -> parse (Yojson.Safe.from_file path))
