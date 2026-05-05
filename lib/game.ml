open Player

let tile_size = 30
let reset_delay = 0.5

type status =
  | Playing
  | Resetting of float

type t = {
  fireboy : player;
  watergirl : player;
  level : Level.t;
  status : status;
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
    level;
    status = Playing;
  }

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
  | Resetting remaining ->
      let remaining' = remaining -. dt in
      if remaining' <= 0. then init s.level
      else { s with status = Resetting remaining' }
  | Playing ->
      let fb = Physics.update dt s.level s.fireboy fb_keys in
      let wg = Physics.update dt s.level s.watergirl wg_keys in
      let fb = check_death fb s.level in
      let wg = check_death wg s.level in
      if (not fb.alive) || not wg.alive then
        { s with fireboy = fb; watergirl = wg; status = Resetting reset_delay }
      else { s with fireboy = fb; watergirl = wg }

let render (s : t) : unit =
  let rp = Render.compute_render_params s.level in
  Render.draw_background rp s.level;
  Render.draw_level rp s.fireboy.anim_timer s.level;
  Render.draw_player rp s.fireboy;
  Render.draw_player rp s.watergirl;
  Render.draw_foreground_tiles rp s.fireboy.anim_timer s.level;
  Render.draw_vignette ()
