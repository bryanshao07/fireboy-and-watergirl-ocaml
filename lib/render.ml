open Player
open Level

let tile_size = 30

type render_params = {
  rts : int;
  offset_x : int;
  offset_y : int;
}

type screen_rect = {
  sx : int;
  sy : int;
  sw : int;
  sh : int;
}

let round_to_int x = int_of_float (x +. 0.5)

let compute_render_params (lvl : Level.t) : render_params =
  let win_w = Graphics.size_x () in
  let win_h = Graphics.size_y () in
  let rts = min (win_w / lvl.width) (win_h / lvl.height) in
  {
    rts;
    offset_x = (win_w - (lvl.width * rts)) / 2;
    offset_y = (win_h - (lvl.height * rts)) / 2;
  }

let render_scale rp = float_of_int rp.rts /. float_of_int tile_size
let scaled_length rp len = max 1 (round_to_int (len *. render_scale rp))

let player_rect (rp : render_params) (p : Player.player) : screen_rect =
  {
    sx = rp.offset_x + round_to_int (p.x *. render_scale rp);
    sy = rp.offset_y + round_to_int (p.y *. render_scale rp);
    sw = scaled_length rp player_width;
    sh = scaled_length rp player_height;
  }

let tile_rect (rp : render_params) col screen_y : screen_rect =
  {
    sx = rp.offset_x + (col * rp.rts);
    sy = rp.offset_y + (screen_y * rp.rts);
    sw = rp.rts;
    sh = rp.rts;
  }

let fireboy_walk = lazy (Sprite.load_anim [ "data/fb_idle0.png" ] 8.0)

let fireboy_idle =
  lazy (Sprite.load_anim [ "data/fb_idle0.png"; "data/fb_idle1.png" ] 8.0)

let sprite_paths_of_tile (t : tile) : string list =
  match t with
  | Fire -> [ "data/lava0.png"; "data/lava1.png" ]
  | Water -> [ "data/water0.png"; "data/water1.png" ]
  | Wall -> [ "data/wall.png" ]
  | Walltop -> [ "data/walltop.png" ]
  | DiamondFire -> [ "data/fire_gem.png" ]
  | DiamondWater -> [ "data/water_gem.png" ]
  | _ -> []

let lava_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Fire) 4.0)
let water_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Water) 4.0)
let wall_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Wall) 4.0)
let walltop_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Walltop) 4.0)
let fire_gem_anim = lazy (Sprite.load_anim (sprite_paths_of_tile DiamondFire) 1.0)
let water_gem_anim = lazy (Sprite.load_anim (sprite_paths_of_tile DiamondWater) 1.0)

let sprite_of_tile (timer : float) (t : tile) : Graphics.image option =
  match t with
  | Fire -> Some (Sprite.frame_of (Lazy.force lava_anim) timer)
  | Water -> Some (Sprite.frame_of (Lazy.force water_anim) timer)
  | Wall -> Some (Sprite.frame_of (Lazy.force wall_anim) timer)
  | Walltop -> Some (Sprite.frame_of (Lazy.force walltop_anim) timer)
  | DiamondFire -> Some (Sprite.frame_of (Lazy.force fire_gem_anim) timer)
  | DiamondWater -> Some (Sprite.frame_of (Lazy.force water_gem_anim) timer)
  | _ -> None

let draws_over_player (t : tile) : bool =
  match t with
  | Fire | Water | Acid -> true
  | _ -> false

(* pick anim based on player state *)
let anim_of (p : Player.player) =
  if Float.abs p.vx > 1.0 then fireboy_walk (* walking *) else fireboy_idle

let draw_player (rp : render_params) (p : Player.player) : unit =
  let anim = anim_of p in
  let frame = Sprite.frame_of (Lazy.force anim) p.anim_timer in
  let rect = player_rect rp p in
  let frame = Sprite.scale_image frame rect.sw rect.sh in

  Graphics.draw_image frame rect.sx rect.sy

let background_tile = lazy (Sprite.load_png "data/background.png")

let draw_background (rp : render_params) (lvl : Level.t) : unit =
  Graphics.set_color Graphics.black;
  Graphics.fill_rect 0 0 (Graphics.size_x ()) (Graphics.size_y ());
  let img = Lazy.force background_tile in
  let img = Sprite.scale_image img rp.rts rp.rts in
  for row = 0 to lvl.height - 1 do
    for col = 0 to lvl.width - 1 do
      Graphics.draw_image img
        (rp.offset_x + (col * rp.rts))
        (rp.offset_y + (row * rp.rts))
    done
  done

let color_of_tile (t : tile) : Graphics.color =
  match t with
  | Empty -> Graphics.white
  | Wall -> Graphics.black
  | Walltop -> Graphics.black
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

let draw_tile rp timer x y tile =
  let rect = tile_rect rp x y in
  match tile with
  | Empty -> ()
  | _ -> (
      match sprite_of_tile timer tile with
      | Some img ->
          let img = Sprite.scale_image img rect.sw rect.sh in
          Graphics.draw_image img rect.sx rect.sy
      | None ->
          Graphics.set_color (color_of_tile tile);
          Graphics.fill_rect rect.sx rect.sy rect.sw rect.sh)

let draw_level rp timer lvl : unit =
  for row = 0 to lvl.height - 1 do
    for col = 0 to lvl.width - 1 do
      let tile = lvl.grid.(row).(col) in

      (* flip y so row 0 appears at top of screen *)
      let screen_y = lvl.height - 1 - row in

      draw_tile rp timer col screen_y tile
    done
  done

let draw_foreground_tiles rp timer lvl : unit =
  for row = 0 to lvl.height - 1 do
    for col = 0 to lvl.width - 1 do
      let tile = lvl.grid.(row).(col) in
      if draws_over_player tile then
        let screen_y = lvl.height - 1 - row in
        draw_tile rp timer col screen_y tile
    done
  done
