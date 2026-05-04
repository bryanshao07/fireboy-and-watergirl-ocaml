open Player
open Render
open Input

let reference_fps = 60.0
let gravity = 0.15 *. reference_fps *. reference_fps
let jump_force = 5.0 *. reference_fps
let speed = 2.0 *. reference_fps
let friction = 0.2 *. reference_fps *. reference_fps

let apply_friction vx dt =
  let drag = friction *. dt in
  if vx > drag then vx -. drag else if vx < -.drag then vx +. drag else 0.0

let to_row py h = h - 1 - (int_of_float py / tile_size)
let solid level c r = Level.is_solid (Level.get level c r)

let update dt level (p : player) (k : keys) : player =
  let h = Level.height level in

  (* calculating horizontal velocity *)
  let vx =
    if k.right && not k.left then speed
    else if k.left && not k.right then -.speed
    else if not p.on_ground then p.vx
    else apply_friction p.vx dt
  in

  let row_lo = to_row (p.y +. 1.) h in
  let row_hi = to_row (p.y +. player_height -. 1.) h in
  let r_min = min row_lo row_hi in
  let r_max = max row_lo row_hi in

  let upd_x = p.x +. (vx *. dt) in
  let x, vx =
    if vx > 0. then (
      let col = int_of_float (upd_x +. player_width -. 1.) / tile_size in
      let blocked = ref false in
      for r = r_min to r_max do
        if solid level col r then blocked := true
      done;
      if !blocked then (float_of_int (col * tile_size) -. player_width, 0.)
      else (upd_x, vx))
    else if vx < 0. then (
      let col = int_of_float upd_x / tile_size in
      let blocked = ref false in
      for r = r_min to r_max do
        if solid level col r then blocked := true
      done;
      if !blocked then (float_of_int ((col + 1) * tile_size), 0.)
      else (upd_x, vx))
    else (upd_x, vx)
  in

  (* calculating vertical velocity*)
  let vy = if k.jump_pressed && p.on_ground then jump_force else p.vy in
  let vy = vy -. (gravity *. dt) in
  let upd_y = p.y +. (vy *. dt) in
  let c_lo = int_of_float x / tile_size in
  let c_hi = int_of_float (x +. player_width -. 1.) / tile_size in
  let y, vy, on_ground =
    if vy <= 0. then (
      let row = to_row upd_y h in
      let hit = ref false in
      for c = c_lo to c_hi do
        if solid level c row then hit := true
      done;
      if !hit then (float_of_int ((h - row) * tile_size), 0., true)
      else (upd_y, vy, false))
    else
      let top_y = upd_y +. player_height in
      let row = to_row top_y h in
      let hit = ref false in
      for c = c_lo to c_hi do
        if solid level c row then hit := true
      done;
      if !hit then
        (float_of_int ((h - 1 - row) * tile_size) -. player_height, 0., false)
      else (upd_y, vy, false)
  in

  { p with x; vx; y; vy; on_ground }
