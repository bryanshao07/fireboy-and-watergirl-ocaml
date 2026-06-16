[@@@coverage off]

open Player
open Level

let tile_size = Level.tile_size

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

let title_thumbnail =
  lazy
    (let raw = Sprite.load_png "data/thumbnail.png" in
     let dump = Graphics.dump_image raw in
     let rh = Array.length dump in
     let rw = if rh = 0 then 1 else Array.length dump.(0) in
     let target_h = 180 in
     let target_w = max 1 (rw * target_h / rh) in
     (Sprite.scale_image raw target_w target_h, target_w))

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

(* Format seconds as M:SS.cc (e.g. 1:23.45) *)
let format_time secs =
  let total_cs = int_of_float (secs *. 100.0) in
  let mins = total_cs / 6000 in
  let s = total_cs / 100 mod 60 in
  let cs = total_cs mod 100 in
  Printf.sprintf "%d:%02d.%02d" mins s cs

let draw_hud (time : float) (red_gems : int) (blue_gems : int) : unit =
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-16-*-*-*-*-*-iso8859-1"
   with _ -> ());
  let h = Graphics.size_y () in
  let time_text = "TIME  " ^ format_time time in
  let red_text = Printf.sprintf "RED  %d" red_gems in
  let blue_text = Printf.sprintf "BLUE  %d" blue_gems in
  let tw, th = Graphics.text_size time_text in
  let rw, _ = Graphics.text_size red_text in
  let bw, _ = Graphics.text_size blue_text in
  let pad = 10 in
  let gap = 20 in
  let panel_w = tw + rw + bw + (pad * 2) + (gap * 2) in
  let panel_h = th + (pad * 2) in
  let panel_x = 14 in
  let panel_y = h - panel_h - 14 in

  (* Panel background *)
  Graphics.set_color (Graphics.rgb 28 24 20);
  Graphics.fill_rect panel_x panel_y panel_w panel_h;
  Graphics.set_color (Graphics.rgb 120 100 50);
  Graphics.draw_rect panel_x panel_y panel_w panel_h;

  (* Time *)
  Graphics.set_color (Graphics.rgb 255 220 90);
  Graphics.moveto (panel_x + pad) (panel_y + pad);
  Graphics.draw_string time_text;

  (* Red gems *)
  Graphics.set_color (Graphics.rgb 255 100 100);
  Graphics.moveto (panel_x + pad + tw + gap) (panel_y + pad);
  Graphics.draw_string red_text;

  (* Blue gems *)
  Graphics.set_color (Graphics.rgb 100 160 255);
  Graphics.moveto (panel_x + pad + tw + gap + rw + gap) (panel_y + pad);
  Graphics.draw_string blue_text

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

let draw_intro (lvl : Level.t) (timer : float) =
  let w = Graphics.size_x () in
  let h = Graphics.size_y () in
  let cx = w / 2 in

  (* Level as background *)
  let rp = compute_render_params lvl in
  draw_background rp lvl;
  draw_level rp timer lvl;

  let title_y = (h / 2) + 60 in

  (* Thumbnail title image *)
  let thumb, thumb_w = Lazy.force title_thumbnail in
  Graphics.draw_image thumb (cx - (thumb_w / 2)) title_y;

  (* Separator *)
  let sep_y = title_y - 8 in
  Graphics.set_color (Graphics.rgb 120 100 50);
  Graphics.moveto (cx - 280) sep_y;
  Graphics.lineto (cx + 280) sep_y;
  Graphics.moveto (cx - 280) (sep_y + 2);
  Graphics.lineto (cx + 280) (sep_y + 2);

  (* PLAY button *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-24-*-*-*-*-*-iso8859-1"
   with _ -> ());
  let btn_text = "PRESS  W / I / SPACE  TO  PLAY" in
  let pt, ph = Graphics.text_size btn_text in
  let btn_w = pt + 60 and btn_h = 60 in
  let btn_x = cx - (btn_w / 2) in
  let btn_y = sep_y - 50 in
  Graphics.set_color (Graphics.rgb 75 55 8);
  Graphics.fill_rect (btn_x + 4) (btn_y - 4) btn_w btn_h;
  Graphics.set_color (Graphics.rgb 185 140 38);
  Graphics.fill_rect btn_x btn_y btn_w btn_h;
  Graphics.set_color (Graphics.rgb 228 190 75);
  Graphics.fill_rect btn_x (btn_y + btn_h - 5) btn_w 5;
  Graphics.set_color (Graphics.rgb 130 95 18);
  Graphics.draw_rect btn_x btn_y btn_w btn_h;
  Graphics.set_color (Graphics.rgb 45 28 0);
  Graphics.moveto (cx - (pt / 2)) (btn_y + ((btn_h - ph) / 2));
  Graphics.draw_string btn_text;

  (* Instructions box + content *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-16-*-*-*-*-*-iso8859-1"
   with _ -> ());
  let instr_y = btn_y - 48 in
  let box_top = instr_y + 30 in
  let box_bot = instr_y - 120 in
  let box_w = 700 in
  let box_x = cx - (box_w / 2) in
  Graphics.set_color (Graphics.rgb 15 13 10);
  Graphics.fill_rect box_x box_bot box_w (box_top - box_bot);
  Graphics.set_color (Graphics.rgb 80 70 45);
  Graphics.draw_rect box_x box_bot box_w (box_top - box_bot);
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
  Graphics.set_color Graphics.white;
  draw_centered cx (instr_y - 76)
    "Fireboy avoids  WATER       Watergirl avoids  FIRE";
  draw_centered cx (instr_y - 96) "Both must reach their exits to win!";

  draw_vignette ()

let draw_win (time : float) (red_gems : int) (blue_gems : int) =
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

  (* Stats panel: TIME, RED gems, BLUE gems *)
  let panel_w = 540 and panel_h = 90 in
  let panel_x = cx - (panel_w / 2) in
  let panel_y = title_y - 220 in
  Graphics.set_color (Graphics.rgb 38 32 18);
  Graphics.fill_rect (panel_x + 3) (panel_y - 3) panel_w panel_h;
  Graphics.set_color (Graphics.rgb 55 46 22);
  Graphics.fill_rect panel_x panel_y panel_w panel_h;
  Graphics.set_color (Graphics.rgb 130 110 55);
  Graphics.draw_rect panel_x panel_y panel_w panel_h;

  (* Vertical dividers between the three columns *)
  let col_w = panel_w / 3 in
  let div1_x = panel_x + col_w in
  let div2_x = panel_x + (col_w * 2) in
  Graphics.set_color (Graphics.rgb 95 78 38);
  Graphics.moveto div1_x (panel_y + 10);
  Graphics.lineto div1_x (panel_y + panel_h - 10);
  Graphics.moveto div2_x (panel_y + 10);
  Graphics.lineto div2_x (panel_y + panel_h - 10);

  let time_cx = panel_x + (col_w / 2) in
  let red_cx = panel_x + col_w + (col_w / 2) in
  let blue_cx = panel_x + (col_w * 2) + (col_w / 2) in

  (* Labels *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-14-*-*-*-*-*-iso8859-1"
   with _ -> ());
  Graphics.set_color (Graphics.rgb 200 175 70);
  draw_centered time_cx (panel_y + panel_h - 22) "TIME";
  Graphics.set_color (Graphics.rgb 255 130 130);
  draw_centered red_cx (panel_y + panel_h - 22) "RED";
  Graphics.set_color (Graphics.rgb 130 175 255);
  draw_centered blue_cx (panel_y + panel_h - 22) "BLUE";

  (* Values *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-24-*-*-*-*-*-iso8859-1"
   with _ -> ());
  Graphics.set_color (Graphics.rgb 255 220 90);
  draw_centered time_cx (panel_y + 18) (format_time time);
  Graphics.set_color (Graphics.rgb 255 130 130);
  draw_centered red_cx (panel_y + 18) (string_of_int red_gems);
  Graphics.set_color (Graphics.rgb 130 175 255);
  draw_centered blue_cx (panel_y + 18) (string_of_int blue_gems);

  (* Play Again button *)
  (try Graphics.set_font "-misc-fixed-bold-r-normal-*-16-*-*-*-*-*-iso8859-1"
   with _ -> ());
  let pa_text = "PRESS  SPACE  TO  PLAY  AGAIN" in
  let pat, pah = Graphics.text_size pa_text in
  let btn_w = pat + 40 and btn_h = 50 in
  let btn_x = cx - (btn_w / 2) in
  let btn_y = panel_y - btn_h - 24 in
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
