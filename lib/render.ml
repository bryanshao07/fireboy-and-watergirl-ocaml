open Player
open Level

let tile_size = 30

let draw_player (p : player) : unit =
  let color =
    match p.character with
    | Fireboy -> Graphics.red
    | Watergirl -> Graphics.blue
  in
  Graphics.set_color color;
  Graphics.fill_rect (int_of_float p.x) (int_of_float p.y)
    (int_of_float player_width)
    (int_of_float player_height)

let color_of_tile (t : tile) : Graphics.color =
  match t with
  | Empty -> Graphics.white
  | Wall -> Graphics.black
  | Fire -> Graphics.red
  | Water -> Graphics.blue
  | Acid -> Graphics.green
  | ExitFire -> Graphics.rgb 255 150 150
  | ExitWater -> Graphics.rgb 150 150 255
  | DiamondFire -> Graphics.rgb 255 100 100
  | DiamondWater -> Graphics.rgb 100 100 255
  | Button -> Graphics.yellow
  | SpawnFire -> Graphics.rgb 255 180 180
  | SpawnWater -> Graphics.rgb 180 180 255

let draw_tile x y tile =
  Graphics.set_color (color_of_tile tile);
  Graphics.fill_rect (x * tile_size) (y * tile_size) tile_size tile_size;
  Graphics.set_color Graphics.black;
  Graphics.draw_rect (x * tile_size) (y * tile_size) tile_size tile_size

let draw_level lvl : unit =
  for row = 0 to lvl.height - 1 do
    for col = 0 to lvl.width - 1 do
      let tile = lvl.grid.(row).(col) in

      (* flip y so row 0 appears at top of screen *)
      let screen_y = lvl.height - 1 - row in

      draw_tile col screen_y tile
    done
  done
