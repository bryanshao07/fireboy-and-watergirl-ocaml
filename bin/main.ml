open Teamproject

type scene =
  | Intro
  | InGame of Game.t
  | Win of { time : float; gems : int }

let () =
  let target_frame_time = 1. /. 60. in
  let max_dt = 1. /. 20. in

  Graphics.open_graph " 1200x700";
  Graphics.set_window_title "Fireboy & Watergirl";
  Graphics.auto_synchronize false;

  let scene = ref Intro in
  let last_frame = ref (Unix.gettimeofday ()) in
  let running = ref true in

  while !running do
    let frame_start = Unix.gettimeofday () in
    let dt = Float.min (frame_start -. !last_frame) max_dt in
    last_frame := frame_start;

    Graphics.clear_graph ();
    Input.drain ();

    (match !scene with
    | Intro ->
        Render.draw_intro ();
        if Input.confirm_just_pressed () then
          scene := InGame (Game.init Level.sample_level)
    | InGame game ->
        let fb_keys = Input.poll_fireboy () in
        let wg_keys = Input.poll_watergirl () in
        let game' = Game.tick dt game fb_keys wg_keys in
        Game.render game';
        (match game'.Game.status with
        | Game.Won ->
            scene := Win { time = game'.Game.elapsed; gems = game'.Game.gems }
        | _ -> scene := InGame game')
    | Win { time; gems } ->
        Render.draw_win time gems;
        if Input.confirm_just_pressed () then
          scene := InGame (Game.init Level.sample_level));

    Graphics.synchronize ();

    if Input.is_held 'q' then running := false;

    let frame_elapsed = Unix.gettimeofday () -. frame_start in
    if frame_elapsed < target_frame_time then
      Unix.sleepf (target_frame_time -. frame_elapsed)
  done