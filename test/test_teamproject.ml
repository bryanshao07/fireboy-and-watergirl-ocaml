open OUnit2
open Teamproject

(* ====================================================================== *)
(* Level                                                                  *)
(* ====================================================================== *)

let test_tile_of_char _ =
  assert_equal Level.Empty (Level.tile_of_char ' ');
  assert_equal Level.Wall (Level.tile_of_char '#');
  assert_equal Level.Walltop (Level.tile_of_char '-');
  assert_equal Level.Fire (Level.tile_of_char 'F');
  assert_equal Level.Water (Level.tile_of_char 'W');
  assert_equal Level.Acid (Level.tile_of_char 'A');
  assert_equal Level.ExitFire (Level.tile_of_char 'E');
  assert_equal Level.ExitWater (Level.tile_of_char 'Q');
  assert_equal Level.DiamondFire (Level.tile_of_char 'R');
  assert_equal Level.DiamondWater (Level.tile_of_char 'B');
  assert_equal Level.Button (Level.tile_of_char 'T');
  assert_equal Level.SpawnFire (Level.tile_of_char '1');
  assert_equal Level.SpawnWater (Level.tile_of_char '2')

let test_tile_of_char_unknown _ =
  assert_raises (Failure "Unknown tile character") (fun () ->
      Level.tile_of_char '?')

let test_dimensions _ =
  let lvl = Level.from_string_list [ "###"; "#1#"; "###" ] in
  assert_equal 3 (Level.width lvl);
  assert_equal 3 (Level.height lvl)

let test_inconsistent_widths _ =
  assert_raises (Failure "All rows must have the same width") (fun () ->
      Level.from_string_list [ "###"; "##" ])

let test_get _ =
  let lvl = Level.from_string_list [ "###"; "#1#"; "###" ] in
  assert_equal Level.Wall (Level.get lvl 0 0);
  assert_equal Level.SpawnFire (Level.get lvl 1 1)

let test_get_out_of_bounds _ =
  let lvl = Level.from_string_list [ "   "; "   " ] in
  assert_equal Level.Wall (Level.get lvl (-1) 0);
  assert_equal Level.Wall (Level.get lvl 99 0);
  assert_equal Level.Wall (Level.get lvl 0 (-1));
  assert_equal Level.Wall (Level.get lvl 0 99)

let test_set _ =
  let lvl = Level.from_string_list [ "   "; "   " ] in
  Level.set lvl 1 1 Level.Fire;
  assert_equal Level.Fire (Level.get lvl 1 1)

let test_set_out_of_bounds_is_noop _ =
  let lvl = Level.from_string_list [ "   "; "   " ] in
  Level.set lvl 99 99 Level.Fire;
  assert_equal Level.Empty (Level.get lvl 0 0)

let test_copy _ =
  let lvl = Level.from_string_list [ "   "; " R " ] in
  let dup = Level.copy lvl in
  Level.set dup 1 1 Level.Empty;
  assert_equal Level.DiamondFire (Level.get lvl 1 1);
  assert_equal Level.Empty (Level.get dup 1 1)

let test_is_solid _ =
  assert_bool "Wall solid" (Level.is_solid Level.Wall);
  assert_bool "Walltop solid" (Level.is_solid Level.Walltop);
  assert_bool "Empty not solid" (not (Level.is_solid Level.Empty));
  assert_bool "Fire not solid" (not (Level.is_solid Level.Fire));
  assert_bool "Water not solid" (not (Level.is_solid Level.Water))

(* ====================================================================== *)
(* Sprite                                                                 *)
(* ====================================================================== *)

let test_image_rows _ =
  let rows = Sprite.image_rows 3 2 (fun x y -> (y * 10) + x) in
  assert_equal [| [| 0; 1; 2 |]; [| 10; 11; 12 |] |] rows

let test_scale_rgba_identity _ =
  let img : Sprite.rgba_image =
    {
      width = 1;
      height = 1;
      pixels = [| [| { r = 5; g = 6; b = 7; a = 255 } |] |];
    }
  in
  let scaled = Sprite.scale_rgba img 1 1 in
  assert_equal img.pixels scaled.pixels

let test_scale_rgba_upscale _ =
  let img : Sprite.rgba_image =
    {
      width = 1;
      height = 1;
      pixels = [| [| { r = 9; g = 9; b = 9; a = 255 } |] |];
    }
  in
  let scaled = Sprite.scale_rgba img 2 2 in
  assert_equal 2 scaled.width;
  assert_equal 2 scaled.height;
  assert_equal { Sprite.r = 9; g = 9; b = 9; a = 255 } scaled.pixels.(0).(0);
  assert_equal { Sprite.r = 9; g = 9; b = 9; a = 255 } scaled.pixels.(1).(1)

let test_scale_rgba_zero _ =
  let img : Sprite.rgba_image =
    { width = 1; height = 1; pixels = [| [| { r = 0; g = 0; b = 0; a = 0 } |] |] }
  in
  assert_equal img (Sprite.scale_rgba img 0 5)

(* ====================================================================== *)
(* Game                                                                   *)
(* ====================================================================== *)

let test_init_status _ =
  let g = Game.init Level.sample_level in
  assert_equal Game.Playing g.status

let test_init_zero_counters _ =
  let g = Game.init Level.sample_level in
  assert_equal 0. g.elapsed;
  assert_equal 0 g.red_gems;
  assert_equal 0 g.blue_gems

let test_init_players_alive _ =
  let g = Game.init Level.sample_level in
  assert_bool "fireboy alive" g.fireboy.alive;
  assert_bool "watergirl alive" g.watergirl.alive

let test_init_player_characters _ =
  let g = Game.init Level.sample_level in
  assert_equal Player.Fireboy g.fireboy.character;
  assert_equal Player.Watergirl g.watergirl.character

let no_keys : Input.keys =
  { left = false; right = false; jump_pressed = false }

let test_won_status_is_sticky _ =
  let g = { (Game.init Level.sample_level) with status = Game.Won } in
  let g' = Game.tick 1.0 g no_keys no_keys in
  assert_equal Game.Won g'.status

let test_won_freezes_elapsed _ =
  let g =
    { (Game.init Level.sample_level) with status = Game.Won; elapsed = 42.0 }
  in
  let g' = Game.tick 1.0 g no_keys no_keys in
  assert_equal 42.0 g'.elapsed

let test_resetting_counts_down _ =
  let g =
    { (Game.init Level.sample_level) with status = Game.Resetting 1.0 }
  in
  let g' = Game.tick 0.3 g no_keys no_keys in
  match g'.status with
  | Game.Resetting r ->
      assert_bool
        (Printf.sprintf "expected r in (0, 1), got %f" r)
        (r > 0. && r < 1.0)
  | _ -> assert_failure "should still be Resetting"

let test_resetting_to_playing _ =
  let g =
    { (Game.init Level.sample_level) with status = Game.Resetting 0.1 }
  in
  let g' = Game.tick 0.5 g no_keys no_keys in
  assert_equal Game.Playing g'.status

let test_resetting_clears_elapsed _ =
  (* When Resetting expires, [init] runs and resets elapsed to 0. *)
  let base = Game.init Level.sample_level in
  let g = { base with status = Game.Resetting 0.05; elapsed = 99.0 } in
  let g' = Game.tick 0.2 g no_keys no_keys in
  assert_equal 0.0 g'.elapsed

let test_tick_advances_elapsed _ =
  let g = Game.init Level.sample_level in
  let g' = Game.tick 0.25 g no_keys no_keys in
  let diff = Float.abs (g'.elapsed -. 0.25) in
  assert_bool
    (Printf.sprintf "expected elapsed ≈ 0.25, got %f" g'.elapsed)
    (diff < 1e-9)

let test_init_does_not_mutate_input _ =
  (* [init] copies the level internally so it can mutate gems on collection
     without affecting the caller's level. *)
  let lvl = Level.copy Level.sample_level in
  let count_red l =
    let n = ref 0 in
    for y = 0 to Level.height l - 1 do
      for x = 0 to Level.width l - 1 do
        if Level.get l x y = Level.DiamondFire then incr n
      done
    done;
    !n
  in
  let before = count_red lvl in
  let _ = Game.init lvl in
  assert_equal before (count_red lvl)

(* ====================================================================== *)
(* Test registration                                                      *)
(* ====================================================================== *)

let tests =
  "Fireboy & Watergirl test suite"
  >::: [
         (* Level *)
         "tile_of_char known"        >:: test_tile_of_char;
         "tile_of_char unknown"      >:: test_tile_of_char_unknown;
         "from_string_list dims"     >:: test_dimensions;
         "from_string_list widths"   >:: test_inconsistent_widths;
         "get in bounds"             >:: test_get;
         "get out of bounds = Wall"  >:: test_get_out_of_bounds;
         "set in bounds"             >:: test_set;
         "set out of bounds noop"    >:: test_set_out_of_bounds_is_noop;
         "copy independence"         >:: test_copy;
         "is_solid"                  >:: test_is_solid;
         (* Sprite *)
         "image_rows indexing"       >:: test_image_rows;
         "scale_rgba identity"       >:: test_scale_rgba_identity;
         "scale_rgba upscales"       >:: test_scale_rgba_upscale;
         "scale_rgba zero size"      >:: test_scale_rgba_zero;
         (* Game *)
         "init status Playing"       >:: test_init_status;
         "init counters zero"        >:: test_init_zero_counters;
         "init players alive"        >:: test_init_players_alive;
         "init characters set"       >:: test_init_player_characters;
         "Won is sticky"             >:: test_won_status_is_sticky;
         "Won freezes elapsed"       >:: test_won_freezes_elapsed;
         "Resetting counts down"     >:: test_resetting_counts_down;
         "Resetting -> Playing"      >:: test_resetting_to_playing;
         "Resetting clears elapsed"  >:: test_resetting_clears_elapsed;
         "tick advances elapsed"     >:: test_tick_advances_elapsed;
         "init copies the level"    >:: test_init_does_not_mutate_input;
       ]

let _ = run_test_tt_main tests