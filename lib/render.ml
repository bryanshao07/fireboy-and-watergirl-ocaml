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

let fireboy_walk_paths =
  [ "data/fb_walk0.png"; "data/fb_walk1.png"; "data/fb_walk2.png" ]

let fireboy_walk = lazy (Sprite.load_anim fireboy_walk_paths 8.0)

let fireboy_idle =
  lazy (Sprite.load_anim [ "data/fb_idle0.png"; "data/fb_idle1.png" ] 8.0)

let watergirl_walk =
  lazy
    (Sprite.load_anim
       [ "data/wg_walk0.png"; "data/wg_walk1.png"; "data/wg_walk2.png" ]
       8.0)

let watergirl_idle = lazy (Sprite.load_anim [ "data/wg_idle0.png" ] 8.0)

let sprite_paths_of_tile (t : tile) : string list =
  match t with
  | Fire -> [ "data/lava0.png"; "data/lava1.png" ]
  | Water -> [ "data/water0.png"; "data/water1.png" ]
  | Acid -> [ "data/acid0.png"; "data/acid1.png" ]
  | Wall -> [ "data/wall.png" ]
  | Walltop -> [ "data/walltop.png" ]
  | DiamondFire -> [ "data/fire_gem.png" ]
  | DiamondWater -> [ "data/water_gem.png" ]
  | ExitFire -> [ "data/fire_exit.png" ]
  | ExitWater -> [ "data/water_exit.png" ]
  | _ -> []

let lava_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Fire) 4.0)
let water_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Water) 4.0)
let acid_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Acid) 4.0)
let wall_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Wall) 4.0)
let walltop_anim = lazy (Sprite.load_anim (sprite_paths_of_tile Walltop) 4.0)

let fire_gem_anim =
  lazy (Sprite.load_anim (sprite_paths_of_tile DiamondFire) 1.0)

let water_gem_anim =
  lazy (Sprite.load_anim (sprite_paths_of_tile DiamondWater) 1.0)

let fire_exit_anim = lazy (Sprite.load_anim (sprite_paths_of_tile ExitFire) 1.0)

let water_exit_anim =
  lazy (Sprite.load_anim (sprite_paths_of_tile ExitWater) 1.0)

let sprite_of_tile (timer : float) (t : tile) : Graphics.image option =
  match t with
  | Fire -> Some (Sprite.frame_of (Lazy.force lava_anim) timer)
  | Water -> Some (Sprite.frame_of (Lazy.force water_anim) timer)
  | Acid -> Some (Sprite.frame_of (Lazy.force acid_anim) timer)
  | Wall -> Some (Sprite.frame_of (Lazy.force wall_anim) timer)
  | Walltop -> Some (Sprite.frame_of (Lazy.force walltop_anim) timer)
  | DiamondFire -> Some (Sprite.frame_of (Lazy.force fire_gem_anim) timer)
  | DiamondWater -> Some (Sprite.frame_of (Lazy.force water_gem_anim) timer)
  | ExitFire -> Some (Sprite.frame_of (Lazy.force fire_exit_anim) timer)
  | ExitWater -> Some (Sprite.frame_of (Lazy.force water_exit_anim) timer)
  | _ -> None

let draws_over_player (t : tile) : bool =
  match t with
  | Fire | Water | Acid -> true
  | _ -> false

(* pick anim based on player state *)
let anim_of (p : Player.player) =
  match p.character with
  | Fireboy -> if Float.abs p.vx > 1.0 then fireboy_walk else fireboy_idle
  | Watergirl -> if Float.abs p.vx > 1.0 then watergirl_walk else watergirl_idle

let draw_player (rp : render_params) (p : Player.player) : unit =
  let anim = anim_of p in
  let frame = Sprite.frame_of (Lazy.force anim) p.anim_timer in
  let frame =
    if p.vx < -1.0 then Sprite.flip_image_horizontally frame else frame
  in
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

let vignette = lazy (Sprite.load_png_rgba "data/vignette.png")
let red c = (c lsr 16) land 0xff
let green c = (c lsr 8) land 0xff
let blue c = c land 0xff

let blend_channel under over alpha =
  ((under * (255 - alpha)) + (over * alpha)) / 255

let blend_pixel under (over : Sprite.rgba_pixel) =
  if over.a <= 0 then under
  else if over.a >= 255 then Graphics.rgb over.r over.g over.b
  else
    Graphics.rgb
      (blend_channel (red under) over.r over.a)
      (blend_channel (green under) over.g over.a)
      (blend_channel (blue under) over.b over.a)

let draw_centered x y text =
  let tw, _ = Graphics.text_size text in
  Graphics.moveto (x - (tw / 2)) y;
  Graphics.draw_string text

let draw_intro () =
  let w = Graphics.size_x () in
  let h = Graphics.size_y () in
  let cx = w / 2 in

  Graphics.set_color (Graphics.rgb 28 24 20);
  Graphics.fill_rect 0 0 w h;

  (* Stone bars at top and bottom *)
  Graphics.set_color (Graphics.rgb 65 58 42);
  Graphics.fill_rect 0 (h - 75) w 75;
  Graphics.fill_rect 0 0 w 75;
  Graphics.set_color (Graphics.rgb 42 37 26);
  Graphics.fill_rect 0 (h - 79) w 4;
  Graphics.fill_rect 0 75 w 4;

  (* Title font *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-24-*-*-*-*-*-iso8859-1"
   with _ -> ());

  let title_y = h * 3 / 4 in
  let box_h = 55 in

  let fb_tw, fb_th = Graphics.text_size "FIREBOY" in
  let amp_tw, _ = Graphics.text_size "&" in
  let wg_tw, wg_th = Graphics.text_size "WATERGIRL" in
  let fb_box_w = max 160 (fb_tw + 50) in
  let wg_box_w = max 210 (wg_tw + 50) in
  let gap = 35 in
  let total_w = fb_box_w + gap + amp_tw + gap + wg_box_w in
  let start_x = cx - (total_w / 2) in

  (* FIREBOY box *)
  Graphics.set_color (Graphics.rgb 90 22 5);
  Graphics.fill_rect start_x title_y fb_box_w box_h;
  Graphics.set_color (Graphics.rgb 145 38 10);
  Graphics.draw_rect start_x title_y fb_box_w box_h;
  Graphics.set_color (Graphics.rgb 255 90 30);
  Graphics.moveto
    (start_x + ((fb_box_w - fb_tw) / 2))
    (title_y + ((box_h - fb_th) / 2));
  Graphics.draw_string "FIREBOY";

  (* & *)
  Graphics.set_color (Graphics.rgb 220 210 200);
  Graphics.moveto (start_x + fb_box_w + gap) (title_y + ((box_h - fb_th) / 2));
  Graphics.draw_string "&";

  (* WATERGIRL box *)
  let wg_box_x = start_x + fb_box_w + gap + amp_tw + gap in
  Graphics.set_color (Graphics.rgb 5 28 75);
  Graphics.fill_rect wg_box_x title_y wg_box_w box_h;
  Graphics.set_color (Graphics.rgb 18 65 145);
  Graphics.draw_rect wg_box_x title_y wg_box_w box_h;
  Graphics.set_color (Graphics.rgb 80 190 255);
  Graphics.moveto
    (wg_box_x + ((wg_box_w - wg_tw) / 2))
    (title_y + ((box_h - wg_th) / 2));
  Graphics.draw_string "WATERGIRL";

  (* Subtitle *)
  (try Graphics.set_font "-misc-fixed-medium-r-normal-*-18-*-*-*-*-*-iso8859-1"
   with _ -> ());
  Graphics.set_color (Graphics.rgb 200 175 70);
  draw_centered cx (title_y - 38) "IN  THE  FOREST  TEMPLE";

  (* Separator *)
  let sep_y = title_y - 62 in
  Graphics.set_color (Graphics.rgb 120 100 50);
  Graphics.moveto (cx - 280) sep_y;
  Graphics.lineto (cx + 280) sep_y;
  Graphics.moveto (cx - 280) (sep_y + 2);
  Graphics.lineto (cx + 280) (sep_y + 2);

  (* PLAY button *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-24-*-*-*-*-*-iso8859-1"
   with _ -> ());
  let btn_w = 200 and btn_h = 60 in
  let btn_x = cx - (btn_w / 2) in
  let btn_y = sep_y - 88 in
  Graphics.set_color (Graphics.rgb 75 55 8);
  Graphics.fill_rect (btn_x + 4) (btn_y - 4) btn_w btn_h;
  Graphics.set_color (Graphics.rgb 185 140 38);
  Graphics.fill_rect btn_x btn_y btn_w btn_h;
  Graphics.set_color (Graphics.rgb 228 190 75);
  Graphics.fill_rect btn_x (btn_y + btn_h - 5) btn_w 5;
  Graphics.set_color (Graphics.rgb 130 95 18);
  Graphics.draw_rect btn_x btn_y btn_w btn_h;
  let pt, ph = Graphics.text_size "PLAY" in
  Graphics.set_color (Graphics.rgb 45 28 0);
  Graphics.moveto (cx - (pt / 2)) (btn_y + ((btn_h - ph) / 2));
  Graphics.draw_string "PLAY";

  (* Instructions header *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-16-*-*-*-*-*-iso8859-1"
   with _ -> ());
  let instr_y = btn_y - 48 in
  Graphics.set_color (Graphics.rgb 175 155 95);
  draw_centered cx instr_y "INSTRUCTIONS";
  let hw, _ = Graphics.text_size "INSTRUCTIONS" in
  Graphics.set_color (Graphics.rgb 130 110 55);
  Graphics.moveto (cx - (hw / 2)) (instr_y - 4);
  Graphics.lineto (cx + (hw / 2)) (instr_y - 4);

  (* Controls *)
  (try Graphics.set_font "-misc-fixed-medium-r-normal-*-14-*-*-*-*-*-iso8859-1"
   with _ -> ());
  Graphics.set_color (Graphics.rgb 255 130 55);
  draw_centered cx (instr_y - 28)
    "Fireboy  ( red )  :   J / L  to move     I  to jump";
  Graphics.set_color (Graphics.rgb 75 185 255);
  draw_centered cx (instr_y - 52)
    "Watergirl  ( blue )  :   A / D  to move     W  to jump";
  Graphics.set_color (Graphics.rgb 155 145 125);
  draw_centered cx (instr_y - 76)
    "Fireboy avoids  WATER       Watergirl avoids  FIRE";
  draw_centered cx (instr_y - 96) "Both must reach their exits to win!";

  (* Footer *)
  (try Graphics.set_font "-misc-fixed-medium-r-normal-*-13-*-*-*-*-*-iso8859-1"
   with _ -> ());
  Graphics.set_color (Graphics.rgb 175 155 75);
  draw_centered cx 45 "Press  SPACE  or  I / W  to start          Q  to quit"

let draw_win () =
  let w = Graphics.size_x () in
  let h = Graphics.size_y () in
  let cx = w / 2 in

  Graphics.set_color (Graphics.rgb 18 22 12);
  Graphics.fill_rect 0 0 w h;

  (* Decorative star clusters *)
  let draw_star x y =
    Graphics.set_color (Graphics.rgb 195 165 38);
    for i = 0 to 5 do
      let a = float_of_int i *. Float.pi /. 3.0 in
      let px = x + int_of_float (22.0 *. cos a) in
      let py = y + int_of_float (22.0 *. sin a) in
      Graphics.fill_circle px py 3
    done;
    Graphics.set_color (Graphics.rgb 255 220 60);
    Graphics.fill_circle x y 7
  in
  draw_star (w / 5) (h * 2 / 3);
  draw_star (w * 4 / 5) (h * 2 / 3);
  draw_star (w / 2) (h * 5 / 6);
  draw_star (w / 5) (h / 2);
  draw_star (w * 4 / 5) (h / 2);

  (* LEVEL COMPLETE! *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-24-*-*-*-*-*-iso8859-1"
   with _ -> ());
  let win_text = "LEVEL  COMPLETE !" in
  let wt, wh = Graphics.text_size win_text in
  let title_y = (h * 3 / 5) + 80 in
  Graphics.set_color (Graphics.rgb 75 62 8);
  Graphics.moveto (cx - (wt / 2) + 3) (title_y - 3);
  Graphics.draw_string win_text;
  Graphics.set_color (Graphics.rgb 255 215 45);
  Graphics.moveto (cx - (wt / 2)) title_y;
  Graphics.draw_string win_text;
  ignore wh;

  (* Subtitle *)
  (try Graphics.set_font "-misc-fixed-medium-r-normal-*-18-*-*-*-*-*-iso8859-1"
   with _ -> ());
  Graphics.set_color (Graphics.rgb 175 225 175);
  draw_centered cx (title_y - 45) "Both players reached their exits!";

  Graphics.set_color (Graphics.rgb 255 100 40);
  draw_centered (cx - 145) (title_y - 78) "Fireboy";
  Graphics.set_color (Graphics.rgb 155 155 155);
  draw_centered cx (title_y - 78) "and";
  Graphics.set_color (Graphics.rgb 55 175 255);
  draw_centered (cx + 145) (title_y - 78) "Watergirl";
  Graphics.set_color (Graphics.rgb 155 155 155);
  draw_centered cx (title_y - 105) "made it out safely!";

  (* Play Again button *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-16-*-*-*-*-*-iso8859-1"
   with _ -> ());
  let pa_text = "PRESS  SPACE  TO  PLAY  AGAIN" in
  let pat, pah = Graphics.text_size pa_text in
  let btn_w = pat + 40 and btn_h = 50 in
  let btn_x = cx - (btn_w / 2) in
  let btn_y = title_y - 170 in
  Graphics.set_color (Graphics.rgb 58 42 6);
  Graphics.fill_rect (btn_x + 3) (btn_y - 3) btn_w btn_h;
  Graphics.set_color (Graphics.rgb 165 125 32);
  Graphics.fill_rect btn_x btn_y btn_w btn_h;
  Graphics.set_color (Graphics.rgb 212 175 62);
  Graphics.fill_rect btn_x (btn_y + btn_h - 5) btn_w 5;
  Graphics.set_color (Graphics.rgb 115 85 12);
  Graphics.draw_rect btn_x btn_y btn_w btn_h;
  Graphics.set_color (Graphics.rgb 38 22 0);
  Graphics.moveto (cx - (pat / 2)) (btn_y + ((btn_h - pah) / 2));
  Graphics.draw_string pa_text;

  (* Quit hint *)
  (try Graphics.set_font "-misc-fixed-medium-r-normal-*-13-*-*-*-*-*-iso8859-1"
   with _ -> ());
  Graphics.set_color (Graphics.rgb 115 105 75);
  draw_centered cx 45 "Q  to quit"

let draw_vignette () : unit =
  let w = Graphics.size_x () in
  let h = Graphics.size_y () in
  let overlay = Sprite.scale_rgba (Lazy.force vignette) w h in
  let screen = Graphics.get_image 0 0 w h |> Graphics.dump_image in
  let blended =
    Sprite.image_rows w h (fun x y ->
        blend_pixel screen.(y).(x) overlay.pixels.(y).(x))
    |> Graphics.make_image
  in
  Graphics.draw_image blended 0 0
