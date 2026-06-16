open Teamproject

type scene =
  | Intro
  | InGame of Game.t
  | Win of { time : float; red_gems : int; blue_gems : int }

(* Levels are played in order; beating one advances to the next. *)
let level_paths = [ "levels/level1.json"; "levels/level2.json" ]

let () =
  let target_frame_time = 1. /. 60. in
  let max_dt = 1. /. 20. in

  let levels =
    level_paths |> List.map Level_loader.load_file |> Array.of_list
  in
  let level_idx = ref 0 in
  let current_level () = levels.(!level_idx) in

  Graphics.open_graph " 1200x700";
  Graphics.set_window_title "Fireboy & Watergirl";
  Graphics.auto_synchronize false;

  let scene = ref Intro in
  let intro_timer = ref 0.0 in
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
        intro_timer := !intro_timer +. dt;
        Render.draw_intro (current_level ()) !intro_timer;
        if Input.confirm_just_pressed () then begin
          intro_timer := 0.0;
          scene := InGame (Game.init (current_level ()))
        end
    | InGame game ->
        let fb_keys = Input.poll_fireboy () in
        let wg_keys = Input.poll_watergirl () in
        let game' = Game.tick dt game fb_keys wg_keys in
        Game.render game';
        (match game'.Game.status with
        | Game.Won ->
            scene :=
              Win
                {
                  time = game'.Game.elapsed;
                  red_gems = game'.Game.red_gems;
                  blue_gems = game'.Game.blue_gems;
                }
        | _ -> scene := InGame game')
    | Win { time; red_gems; blue_gems } ->
        Render.draw_win time red_gems blue_gems;
        if Input.confirm_just_pressed () then
          if !level_idx + 1 < Array.length levels then begin
            (* advance to the next level *)
            incr level_idx;
            scene := InGame (Game.init (current_level ()))
          end
          else begin
            (* finished the last level: back to the first level's intro *)
            level_idx := 0;
            intro_timer := 0.0;
            scene := Intro
          end);

    Graphics.synchronize ();

    if Input.is_held 'q' then running := false;
    if Input.is_held 'r' then (scene := Intro; intro_timer := 0.);

    let frame_elapsed = Unix.gettimeofday () -. frame_start in
    if frame_elapsed < target_frame_time then
      Unix.sleepf (target_frame_time -. frame_elapsed)
  done
