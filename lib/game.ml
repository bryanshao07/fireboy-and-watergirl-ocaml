open Player

let tile_size = 30
let reset_delay = 0.5

type status =
  | Playing
  | Resetting of float
  | Won

type t = {
  fireboy : player;
  watergirl : player;
  level : Level.t;
  original_level : Level.t;
  status : status;
  elapsed : float;
  red_gems : int;
  blue_gems : int;
}

let pixel_to_tile (px : float) (py : float) (lvl : Level.t) : int * int =
  let tx = int_of_float px / tile_size in
  let height_px = Level.height lvl * tile_size in
  let ty = (height_px - int_of_float py) / tile_size in
  (tx, ty)

let tile_to_pixel_center (tx : int) (ty : int) (lvl : Level.t) : float * float =
  let px = float_of_int ((tx * tile_size) + (tile_size / 2)) in
  let height_px = Level.height lvl * tile_size in
  let py = float_of_int (height_px - (ty * tile_size) - (tile_size / 2)) in
  (px, py)

let tile_to_player_lower_left (tx : int) (ty : int) (lvl : Level.t) :
    float * float =
  let px =
    float_of_int (tx * tile_size)
    +. ((float_of_int tile_size -. player_width) /. 2.)
  in
  let height_px = Level.height lvl * tile_size in
  let py = float_of_int (height_px - ((ty + 1) * tile_size)) in
  (px, py)

let find_spawn (target : Level.tile) (lvl : Level.t) : float * float =
  let result = ref None in
  for y = 0 to Level.height lvl - 1 do
    for x = 0 to Level.width lvl - 1 do
      if Level.get lvl x y = target && !result = None then
        result := Some (tile_to_player_lower_left x y lvl)
    done
  done;
  match !result with
  | Some pos -> pos
  | None -> (100., 100.)

let fireboy_spawn_of (lvl : Level.t) : float * float =
  find_spawn Level.SpawnFire lvl

let watergirl_spawn_of (lvl : Level.t) : float * float =
  find_spawn Level.SpawnWater lvl

let spawn_fireboy (x, y) : player =
  {
    x;
    y;
    vx = 0.;
    vy = 0.;
    on_ground = false;
    character = Fireboy;
    alive = true;
    anim_timer = 0.;
  }

let spawn_watergirl (x, y) : player =
  {
    x;
    y;
    vx = 0.;
    vy = 0.;
    on_ground = false;
    character = Watergirl;
    alive = true;
    anim_timer = 0.;
  }

let init (level : Level.t) : t =
  {
    fireboy = spawn_fireboy (fireboy_spawn_of level);
    watergirl = spawn_watergirl (watergirl_spawn_of level);
    level = Level.copy level;
    original_level = level;
    status = Playing;
    elapsed = 0.;
    red_gems = 0;
    blue_gems = 0;
  }

let check_win (fb : player) (wg : player) (level : Level.t) : bool =
  let center_tile p =
    pixel_to_tile
      (p.x +. (player_width /. 2.))
      (p.y +. (player_height /. 2.))
      level
  in
  let ftx, fty = center_tile fb in
  let wtx, wty = center_tile wg in
  Level.get level ftx fty = Level.ExitFire
  && Level.get level wtx wty = Level.ExitWater

let collect_diamonds (p : player) (level : Level.t) : int * int =
  let h = Level.height level in
  let col_lo = int_of_float p.x / tile_size in
  let col_hi = int_of_float (p.x +. player_width -. 1.) / tile_size in
  let row_lo =
    h - 1 - (int_of_float (p.y +. player_height -. 1.) / tile_size)
  in
  let row_hi = h - 1 - (int_of_float p.y / tile_size) in
  let red = ref 0 in
  let blue = ref 0 in
  for r = row_lo to row_hi do
    for c = col_lo to col_hi do
      match (p.character, Level.get level c r) with
      | Fireboy, Level.DiamondFire ->
          Level.set level c r Level.Empty;
          incr red
      | Watergirl, Level.DiamondWater ->
          Level.set level c r Level.Empty;
          incr blue
      | _ -> ()
    done
  done;
  (!red, !blue)

let check_death (p : player) (level : Level.t) : player =
  let tx, ty =
    pixel_to_tile
      (p.x +. (player_width /. 2.))
      (p.y +. (player_height /. 2.))
      level
  in
  let tile = Level.get level tx ty in
  let dies =
    match (p.character, tile) with
    | Fireboy, Level.Water -> true
    | Watergirl, Level.Fire -> true
    | _, Level.Acid -> true
    | _, _ -> false
  in
  if dies then { p with alive = false } else p

let tick (dt : float) (s : t) (fb_keys : Input.keys) (wg_keys : Input.keys) : t
    =
  match s.status with
  | Won -> s
  | Resetting remaining ->
      let remaining' = remaining -. dt in
      if remaining' <= 0. then init s.original_level
      else { s with status = Resetting remaining' }
  | Playing ->
      let fb = Physics.update dt s.level s.fireboy fb_keys in
      let wg = Physics.update dt s.level s.watergirl wg_keys in
      let fb = check_death fb s.level in
      let wg = check_death wg s.level in
      let red_fb, _ = collect_diamonds fb s.level in
      let _, blue_wg = collect_diamonds wg s.level in
      let red_gems = s.red_gems + red_fb in
      let blue_gems = s.blue_gems + blue_wg in
      let elapsed' = s.elapsed +. dt in
      if (not fb.alive) || not wg.alive then
        {
          s with
          fireboy = fb;
          watergirl = wg;
          status = Resetting reset_delay;
          elapsed = elapsed';
          red_gems;
          blue_gems;
        }
      else if check_win fb wg s.level then
        {
          s with
          fireboy = fb;
          watergirl = wg;
          status = Won;
          elapsed = elapsed';
          red_gems;
          blue_gems;
        }
      else
        {
          s with
          fireboy = fb;
          watergirl = wg;
          elapsed = elapsed';
          red_gems;
          blue_gems;
        }

let render (s : t) : unit =
  let rp = Render.compute_render_params s.level in
  Render.draw_background rp s.level;
  Render.draw_level rp s.fireboy.anim_timer s.level;
  Render.draw_player rp s.fireboy;
  Render.draw_player rp s.watergirl;
  Render.draw_foreground_tiles rp s.fireboy.anim_timer s.level;
  Render.draw_vignette ();
  Render.draw_hud s.elapsed s.red_gems s.blue_gems
