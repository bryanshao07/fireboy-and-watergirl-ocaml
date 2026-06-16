open OUnit2
open Teamproject

(* ====================================================================== *)
(* Printers                                                               *)
(* ====================================================================== *)

let pp_tile = function
  | Level.Empty -> "Empty"
  | Level.Wall -> "Wall"
  | Level.Walltop -> "Walltop"
  | Level.Fire -> "Fire"
  | Level.Water -> "Water"
  | Level.Acid -> "Acid"
  | Level.ExitFire -> "ExitFire"
  | Level.ExitWater -> "ExitWater"
  | Level.DiamondFire -> "DiamondFire"
  | Level.DiamondWater -> "DiamondWater"
  | Level.Button -> "Button"
  | Level.SpawnFire -> "SpawnFire"
  | Level.SpawnWater -> "SpawnWater"

let pp_int_array arr =
  "[|" ^ String.concat "; " (List.map string_of_int (Array.to_list arr)) ^ "|]"

let pp_int_array_array rows =
  "[|" ^ String.concat "; " (List.map pp_int_array (Array.to_list rows)) ^ "|]"

let pp_rgba_pixel p =
  Printf.sprintf "{r=%d; g=%d; b=%d; a=%d}" p.Sprite.r p.Sprite.g p.Sprite.b
    p.Sprite.a

let pp_rgba_pixel_row row =
  "[|" ^ String.concat "; " (List.map pp_rgba_pixel (Array.to_list row)) ^ "|]"

let pp_rgba_pixel_array_array rows =
  "[|"
  ^ String.concat "; " (List.map pp_rgba_pixel_row (Array.to_list rows))
  ^ "|]"

let pp_rgba_image img =
  Printf.sprintf "{width=%d; height=%d; pixels=%s}" img.Sprite.width
    img.Sprite.height
    (pp_rgba_pixel_array_array img.Sprite.pixels)

let pp_char = function
  | Player.Fireboy -> "Fireboy"
  | Player.Watergirl -> "Watergirl"

let pp_status = function
  | Game.Playing -> "Playing"
  | Game.Won -> "Won"
  | Game.Resetting r -> Printf.sprintf "Resetting %.4f" r

(* ====================================================================== *)
(* Level                                                                  *)
(* ====================================================================== *)

let test_tile_of_char _ =
  assert_equal ~printer:pp_tile Level.Empty (Level.tile_of_char ' ');
  assert_equal ~printer:pp_tile Level.Wall (Level.tile_of_char '#');
  assert_equal ~printer:pp_tile Level.Walltop (Level.tile_of_char '-');
  assert_equal ~printer:pp_tile Level.Fire (Level.tile_of_char 'F');
  assert_equal ~printer:pp_tile Level.Water (Level.tile_of_char 'W');
  assert_equal ~printer:pp_tile Level.Acid (Level.tile_of_char 'A');
  assert_equal ~printer:pp_tile Level.ExitFire (Level.tile_of_char 'E');
  assert_equal ~printer:pp_tile Level.ExitWater (Level.tile_of_char 'Q');
  assert_equal ~printer:pp_tile Level.DiamondFire (Level.tile_of_char 'R');
  assert_equal ~printer:pp_tile Level.DiamondWater (Level.tile_of_char 'B');
  assert_equal ~printer:pp_tile Level.Button (Level.tile_of_char 'T');
  assert_equal ~printer:pp_tile Level.SpawnFire (Level.tile_of_char '1');
  assert_equal ~printer:pp_tile Level.SpawnWater (Level.tile_of_char '2')

let test_tile_of_char_unknown _ =
  assert_raises (Failure "Unknown tile character") (fun () ->
      Level.tile_of_char '?')

let test_dimensions _ =
  let lvl = Level.from_string_list [ "###"; "#1#"; "###" ] in
  assert_equal ~printer:string_of_int 3 (Level.width lvl);
  assert_equal ~printer:string_of_int 3 (Level.height lvl)

let test_inconsistent_widths _ =
  assert_raises (Failure "All rows must have the same width") (fun () ->
      Level.from_string_list [ "###"; "##" ])

let test_get _ =
  let lvl = Level.from_string_list [ "###"; "#1#"; "###" ] in
  assert_equal ~printer:pp_tile Level.Wall (Level.get lvl 0 0);
  assert_equal ~printer:pp_tile Level.SpawnFire (Level.get lvl 1 1)

let test_get_out_of_bounds _ =
  let lvl = Level.from_string_list [ "   "; "   " ] in
  assert_equal ~printer:pp_tile Level.Wall (Level.get lvl (-1) 0);
  assert_equal ~printer:pp_tile Level.Wall (Level.get lvl 99 0);
  assert_equal ~printer:pp_tile Level.Wall (Level.get lvl 0 (-1));
  assert_equal ~printer:pp_tile Level.Wall (Level.get lvl 0 99)

let test_set _ =
  let lvl = Level.from_string_list [ "   "; "   " ] in
  Level.set lvl 1 1 Level.Fire;
  assert_equal ~printer:pp_tile Level.Fire (Level.get lvl 1 1)

let test_set_out_of_bounds_is_noop _ =
  let lvl = Level.from_string_list [ "   "; "   " ] in
  Level.set lvl 99 99 Level.Fire;
  assert_equal ~printer:pp_tile Level.Empty (Level.get lvl 0 0)

let test_copy _ =
  let lvl = Level.from_string_list [ "   "; " R " ] in
  let dup = Level.copy lvl in
  Level.set dup 1 1 Level.Empty;
  assert_equal ~printer:pp_tile Level.DiamondFire (Level.get lvl 1 1);
  assert_equal ~printer:pp_tile Level.Empty (Level.get dup 1 1)

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
  assert_equal ~printer:pp_int_array_array
    [| [| 0; 1; 2 |]; [| 10; 11; 12 |] |]
    rows

let test_scale_rgba_identity _ =
  let img : Sprite.rgba_image =
    {
      width = 1;
      height = 1;
      pixels = [| [| { r = 5; g = 6; b = 7; a = 255 } |] |];
    }
  in
  let scaled = Sprite.scale_rgba img 1 1 in
  assert_equal ~printer:pp_rgba_pixel_array_array img.pixels scaled.pixels

let test_scale_rgba_upscale _ =
  let img : Sprite.rgba_image =
    {
      width = 1;
      height = 1;
      pixels = [| [| { r = 9; g = 9; b = 9; a = 255 } |] |];
    }
  in
  let scaled = Sprite.scale_rgba img 2 2 in
  assert_equal ~printer:string_of_int 2 scaled.width;
  assert_equal ~printer:string_of_int 2 scaled.height;
  assert_equal ~printer:pp_rgba_pixel
    { Sprite.r = 9; g = 9; b = 9; a = 255 }
    scaled.pixels.(0).(0);
  assert_equal ~printer:pp_rgba_pixel
    { Sprite.r = 9; g = 9; b = 9; a = 255 }
    scaled.pixels.(1).(1)

let test_scale_rgba_zero _ =
  let img : Sprite.rgba_image =
    {
      width = 1;
      height = 1;
      pixels = [| [| { r = 0; g = 0; b = 0; a = 0 } |] |];
    }
  in
  assert_equal ~printer:pp_rgba_image img (Sprite.scale_rgba img 0 5)

let test_scale_rgba_zero_height _ =
  let img : Sprite.rgba_image =
    {
      width = 1;
      height = 1;
      pixels = [| [| { r = 1; g = 2; b = 3; a = 255 } |] |];
    }
  in
  assert_equal ~printer:pp_rgba_image img (Sprite.scale_rgba img 5 0)

let test_scale_rgba_zero_src_width _ =
  let img : Sprite.rgba_image = { width = 0; height = 0; pixels = [||] } in
  assert_equal ~printer:pp_rgba_image img (Sprite.scale_rgba img 5 5)

let test_scale_rgba_zero_src_height _ =
  let img : Sprite.rgba_image = { width = 1; height = 0; pixels = [||] } in
  assert_equal ~printer:pp_rgba_image img (Sprite.scale_rgba img 5 5)

let test_flip_rows_horizontally _ =
  let rows = [| [| 1; 2; 3 |]; [| 4; 5; 6 |] |] in
  let f = Sprite.flip_rows_horizontally rows in
  assert_equal ~printer:pp_int_array [| 3; 2; 1 |] f.(0);
  assert_equal ~printer:pp_int_array [| 6; 5; 4 |] f.(1)

(* ====================================================================== *)
(* Level (additional)                                                     *)
(* ====================================================================== *)

let test_from_empty_list _ =
  let lvl = Level.from_string_list [] in
  assert_equal ~printer:string_of_int 0 (Level.width lvl);
  assert_equal ~printer:string_of_int 0 (Level.height lvl)

(* ====================================================================== *)
(* Level_loader (JSON)                                                    *)
(* ====================================================================== *)

let sample_json =
  {|{
    "name": "Test",
    "width": 3,
    "height": 2,
    "legend": { " ": "empty", "#": "wall", "1": "spawn_fire", "F": "fire_pool" },
    "grid": [ "###", "#1F" ]
  }|}

let test_loader_dimensions _ =
  let lvl = Level_loader.load_string sample_json in
  assert_equal ~printer:string_of_int 3 (Level.width lvl);
  assert_equal ~printer:string_of_int 2 (Level.height lvl)

let test_loader_tiles _ =
  let lvl = Level_loader.load_string sample_json in
  assert_equal ~printer:pp_tile Level.Wall (Level.get lvl 0 0);
  assert_equal ~printer:pp_tile Level.SpawnFire (Level.get lvl 1 1);
  assert_equal ~printer:pp_tile Level.Fire (Level.get lvl 2 1)

let test_loader_tile_of_name _ =
  assert_equal ~printer:pp_tile Level.Walltop
    (Level_loader.tile_of_name "platform");
  assert_equal ~printer:pp_tile Level.ExitWater
    (Level_loader.tile_of_name "water_door")

let test_loader_unknown_tile_name _ =
  assert_raises (Failure "Unknown tile name \"lava\" in legend") (fun () ->
      Level_loader.tile_of_name "lava")

let test_loader_bad_row_width _ =
  let json =
    {|{ "name":"x", "width":3, "height":1,
        "legend": {"#":"wall"}, "grid": ["##"] }|}
  in
  assert_raises (Failure "grid row \"##\" has length 2 but width is 3")
    (fun () -> Level_loader.load_string json)

let test_loader_char_not_in_legend _ =
  let json =
    {|{ "name":"x", "width":2, "height":1,
        "legend": {"#":"wall"}, "grid": ["#?"] }|}
  in
  assert_raises (Failure "grid character '?' is not defined in the legend")
    (fun () -> Level_loader.load_string json)

(* ====================================================================== *)
(* Physics                                                                *)
(* ====================================================================== *)

(* 5-row x 10-col enclosed arena. Floor = grid row 4, ceiling = row 0. Player
   standing on floor has y = 30. Right wall col 9, left wall col 0. *)
let phys_level =
  Level.from_string_list
    [ "##########"; "#        #"; "#        #"; "#        #"; "##########" ]

let make_fb ?(x = 100.) ?(y = 30.) ?(vx = 0.) ?(vy = 0.) ?(on_ground = true) ()
    : Player.player =
  {
    Player.x;
    y;
    vx;
    vy;
    on_ground;
    character = Player.Fireboy;
    alive = true;
    anim_timer = 0.;
  }

let no_keys : Input.keys =
  { Input.left = false; right = false; jump_pressed = false }

let right_keys : Input.keys =
  { Input.left = false; right = true; jump_pressed = false }

let left_keys : Input.keys =
  { Input.left = true; right = false; jump_pressed = false }

let jump_keys : Input.keys =
  { Input.left = false; right = false; jump_pressed = true }

let test_physics_move_right _ =
  let p = make_fb ~x:100. ~y:30. ~on_ground:true () in
  let p' = Physics.update 0.016 phys_level p right_keys in
  assert_bool "moved right" (p'.Player.x > 100.)

let test_physics_move_left _ =
  let p = make_fb ~x:100. ~y:30. ~on_ground:true () in
  let p' = Physics.update 0.016 phys_level p left_keys in
  assert_bool "moved left" (p'.Player.x < 100.)

let test_physics_friction_positive _ =
  (* vx=50, on_ground, no keys -> friction reduces vx toward zero *)
  let p = make_fb ~x:100. ~y:30. ~vx:50. ~on_ground:true () in
  let p' = Physics.update 0.016 phys_level p no_keys in
  assert_bool "friction slows positive vx"
    (p'.Player.vx >= 0. && p'.Player.vx < 50.)

let test_physics_friction_negative _ =
  (* vx=-50, on_ground, no keys -> friction reduces magnitude *)
  let p = make_fb ~x:100. ~y:30. ~vx:(-50.) ~on_ground:true () in
  let p' = Physics.update 0.016 phys_level p no_keys in
  assert_bool "friction slows negative vx"
    (p'.Player.vx <= 0. && p'.Player.vx > -50.)

let test_physics_friction_zero _ =
  (* vx=5 < drag (720*0.016=11.52) -> zeroed; vx=0 path in collision code *)
  let p = make_fb ~x:100. ~y:30. ~vx:5. ~on_ground:true () in
  let p' = Physics.update 0.016 phys_level p no_keys in
  assert_equal ~printer:string_of_float 0. p'.Player.vx

let test_physics_airborne_keeps_vx _ =
  (* not on_ground, no keys -> vx = p.vx unchanged *)
  let p = make_fb ~x:100. ~y:60. ~vx:10. ~on_ground:false () in
  let p' = Physics.update 0.016 phys_level p no_keys in
  assert_equal ~printer:string_of_float 10. p'.Player.vx

let test_physics_jump _ =
  let p = make_fb ~x:100. ~y:30. ~on_ground:true () in
  let p' = Physics.update 0.016 phys_level p jump_keys in
  assert_bool "jump gives upward vy" (p'.Player.vy > 0.)

let test_physics_right_wall _ =
  (* player near right wall moving right -> snapped, vx zeroed *)
  let p = make_fb ~x:241. ~y:30. ~on_ground:true () in
  let p' = Physics.update 0.05 phys_level p right_keys in
  assert_equal ~printer:string_of_float 0. p'.Player.vx;
  assert_equal ~printer:string_of_float 240. p'.Player.x

let test_physics_left_wall _ =
  (* player near left wall moving left -> snapped, vx zeroed *)
  let p = make_fb ~x:31. ~y:30. ~on_ground:true () in
  let p' = Physics.update 0.05 phys_level p left_keys in
  assert_equal ~printer:string_of_float 0. p'.Player.vx;
  assert_equal ~printer:string_of_float 30. p'.Player.x

let test_physics_floor_landing _ =
  let p = make_fb ~x:100. ~y:31. ~vy:(-200.) ~on_ground:false () in
  let p' = Physics.update 0.016 phys_level p no_keys in
  assert_bool "landed" p'.Player.on_ground

let test_physics_ceiling_hit _ =
  (* large upward vy -> hits ceiling -> vy zeroed, not on_ground *)
  let p = make_fb ~x:100. ~y:70. ~vy:600. ~on_ground:false () in
  let p' = Physics.update 0.05 phys_level p no_keys in
  assert_equal ~printer:string_of_float 0. p'.Player.vy;
  assert_bool "not on ground after ceiling" (not p'.Player.on_ground)

(* ====================================================================== *)
(* Game                                                                   *)
(* ====================================================================== *)

let make_player ?(x = 30.) ?(y = 30.) ?(alive = true) ch : Player.player =
  {
    Player.x;
    y;
    vx = 0.;
    vy = 0.;
    on_ground = false;
    character = ch;
    alive;
    anim_timer = 0.;
  }

let water_lvl = Level.from_string_list [ "###"; "#W#"; "###" ]
let fire_lvl = Level.from_string_list [ "###"; "#F#"; "###" ]
let acid_lvl = Level.from_string_list [ "###"; "#A#"; "###" ]
let safe_lvl = Level.from_string_list [ "###"; "# #"; "###" ]
let exit_lvl = Level.from_string_list [ "###"; "EQ#"; "###" ]
let gem_fire_lvl = Level.from_string_list [ "###"; "#R#"; "###" ]
let gem_water_lvl = Level.from_string_list [ "###"; "#B#"; "###" ]

let test_check_death_fireboy_water _ =
  let fb = make_player Player.Fireboy in
  let fb' = Game.check_death fb water_lvl in
  assert_bool "fireboy dies in water" (not fb'.Player.alive)

let test_check_death_watergirl_fire _ =
  let wg = make_player Player.Watergirl in
  let wg' = Game.check_death wg fire_lvl in
  assert_bool "watergirl dies in fire" (not wg'.Player.alive)

let test_check_death_acid _ =
  let fb = make_player Player.Fireboy in
  let fb' = Game.check_death fb acid_lvl in
  assert_bool "dies in acid" (not fb'.Player.alive)

let test_check_death_safe _ =
  let fb = make_player Player.Fireboy in
  let fb' = Game.check_death fb safe_lvl in
  assert_bool "safe in empty tile" fb'.Player.alive

let test_check_win_true _ =
  (* fb center at tile (0,1)=ExitFire, wg center at tile (1,1)=ExitWater *)
  let fb = make_player ~x:0. ~y:22. Player.Fireboy in
  let wg = make_player ~x:30. ~y:22. Player.Watergirl in
  assert_bool "win condition true" (Game.check_win fb wg exit_lvl)

let test_check_win_false _ =
  let fb = make_player ~x:30. ~y:30. Player.Fireboy in
  let wg = make_player ~x:30. ~y:30. Player.Watergirl in
  assert_bool "win condition false" (not (Game.check_win fb wg safe_lvl))

let test_collect_diamonds_fireboy _ =
  let fb = make_player Player.Fireboy in
  let lvl = Level.copy gem_fire_lvl in
  let red, blue = Game.collect_diamonds fb lvl in
  assert_equal ~printer:string_of_int 1 red;
  assert_equal ~printer:string_of_int 0 blue

let test_collect_diamonds_watergirl _ =
  let wg = make_player Player.Watergirl in
  let lvl = Level.copy gem_water_lvl in
  let red, blue = Game.collect_diamonds wg lvl in
  assert_equal ~printer:string_of_int 0 red;
  assert_equal ~printer:string_of_int 1 blue

let test_collect_diamonds_none _ =
  let fb = make_player Player.Fireboy in
  let lvl = Level.copy safe_lvl in
  let red, blue = Game.collect_diamonds fb lvl in
  assert_equal ~printer:string_of_int 0 red;
  assert_equal ~printer:string_of_int 0 blue

let test_tile_to_pixel_center _ =
  (* exit_lvl is 3x3; tile (0,1): px=15, py=90-30-15=45 *)
  let px, py = Game.tile_to_pixel_center 0 1 exit_lvl in
  assert_equal ~printer:string_of_float 15. px;
  assert_equal ~printer:string_of_float 45. py

let test_fireboy_spawn_of _ =
  let lvl = Level.from_string_list [ "###"; "#1#"; "###" ] in
  let x, y = Game.fireboy_spawn_of lvl in
  assert_equal ~printer:string_of_float 30. x;
  assert_equal ~printer:string_of_float 30. y

let test_fireboy_spawn_no_tile _ =
  (* No SpawnFire in level -> fallback (100., 100.) *)
  let x, y = Game.fireboy_spawn_of safe_lvl in
  assert_equal ~printer:string_of_float 100. x;
  assert_equal ~printer:string_of_float 100. y

let test_fireboy_spawn_two_tiles _ =
  (* Two SpawnFire tiles: find_spawn takes first, skips second (!result=None is
     false) *)
  let lvl = Level.from_string_list [ "###"; "#1#"; "#1#" ] in
  let x, _ = Game.fireboy_spawn_of lvl in
  assert_bool "spawn found" (x >= 0.)

let test_spawn_fireboy _ =
  let p = Game.spawn_fireboy (10., 20.) in
  assert_equal ~printer:pp_char Player.Fireboy p.Player.character;
  assert_equal ~printer:string_of_float 10. p.Player.x;
  assert_equal ~printer:string_of_float 20. p.Player.y;
  assert_bool "alive" p.Player.alive

let test_spawn_watergirl _ =
  let p = Game.spawn_watergirl (5., 15.) in
  assert_equal ~printer:pp_char Player.Watergirl p.Player.character;
  assert_equal ~printer:string_of_float 5. p.Player.x;
  assert_equal ~printer:string_of_float 15. p.Player.y;
  assert_bool "alive" p.Player.alive

let test_tick_player_death _ =
  (* Fireboy starts inside water tile -> dies -> Resetting *)
  let base = Game.init water_lvl in
  let g =
    {
      base with
      Game.fireboy = { base.Game.fireboy with Player.x = 30.; y = 30. };
      watergirl = { base.Game.watergirl with Player.x = 30.; y = 30. };
    }
  in
  let g' = Game.tick 0.016 g no_keys no_keys in
  match g'.Game.status with
  | Game.Resetting _ -> ()
  | _ -> assert_failure "expected Resetting after death"

let test_tick_watergirl_death _ =
  (* Fireboy safe in fire, watergirl dies -> covers right side of || in tick *)
  let base = Game.init fire_lvl in
  let g =
    {
      base with
      Game.fireboy = { base.Game.fireboy with Player.x = 30.; y = 30. };
      watergirl = { base.Game.watergirl with Player.x = 30.; y = 30. };
    }
  in
  let g' = Game.tick 0.016 g no_keys no_keys in
  match g'.Game.status with
  | Game.Resetting _ -> ()
  | _ -> assert_failure "expected Resetting after watergirl death"

let test_tick_win_condition _ =
  (* Both players at exit tiles -> Won *)
  let base = Game.init exit_lvl in
  let g =
    {
      base with
      Game.fireboy = { base.Game.fireboy with Player.x = 0.; y = 22. };
      watergirl = { base.Game.watergirl with Player.x = 30.; y = 22. };
    }
  in
  let g' = Game.tick 0.016 g no_keys no_keys in
  assert_equal ~printer:pp_status Game.Won g'.Game.status

let test_init_status _ =
  let g = Game.init Level.level_one in
  assert_equal ~printer:pp_status Game.Playing g.status

let test_init_zero_counters _ =
  let g = Game.init Level.level_one in
  assert_equal ~printer:string_of_float 0. g.elapsed;
  assert_equal ~printer:string_of_int 0 g.red_gems;
  assert_equal ~printer:string_of_int 0 g.blue_gems

let test_init_players_alive _ =
  let g = Game.init Level.level_one in
  assert_bool "fireboy alive" g.fireboy.alive;
  assert_bool "watergirl alive" g.watergirl.alive

let test_init_player_characters _ =
  let g = Game.init Level.level_one in
  assert_equal ~printer:pp_char Player.Fireboy g.fireboy.character;
  assert_equal ~printer:pp_char Player.Watergirl g.watergirl.character

let test_won_status_is_sticky _ =
  let g = { (Game.init Level.level_one) with status = Game.Won } in
  let g' = Game.tick 1.0 g no_keys no_keys in
  assert_equal ~printer:pp_status Game.Won g'.status

let test_won_freezes_elapsed _ =
  let g =
    { (Game.init Level.level_one) with status = Game.Won; elapsed = 42.0 }
  in
  let g' = Game.tick 1.0 g no_keys no_keys in
  assert_equal ~printer:string_of_float 42.0 g'.elapsed

let test_resetting_counts_down _ =
  let g = { (Game.init Level.level_one) with status = Game.Resetting 1.0 } in
  let g' = Game.tick 0.3 g no_keys no_keys in
  match g'.status with
  | Game.Resetting r ->
      assert_bool
        (Printf.sprintf "expected r in (0, 1), got %f" r)
        (r > 0. && r < 1.0)
  | _ -> assert_failure "should still be Resetting"

let test_resetting_to_playing _ =
  let g = { (Game.init Level.level_one) with status = Game.Resetting 0.1 } in
  let g' = Game.tick 0.5 g no_keys no_keys in
  assert_equal ~printer:pp_status Game.Playing g'.status

let test_resetting_clears_elapsed _ =
  (* When Resetting expires, [init] runs and resets elapsed to 0. *)
  let base = Game.init Level.level_one in
  let g = { base with status = Game.Resetting 0.05; elapsed = 99.0 } in
  let g' = Game.tick 0.2 g no_keys no_keys in
  assert_equal ~printer:string_of_float 0.0 g'.elapsed

let test_tick_advances_elapsed _ =
  let g = Game.init Level.level_one in
  let g' = Game.tick 0.25 g no_keys no_keys in
  let diff = Float.abs (g'.elapsed -. 0.25) in
  assert_bool
    (Printf.sprintf "expected elapsed ≈ 0.25, got %f" g'.elapsed)
    (diff < 1e-9)

let test_init_does_not_mutate_input _ =
  (* [init] copies the level internally so it can mutate gems on collection
     without affecting the caller's level. *)
  let lvl = Level.copy Level.level_one in
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
  assert_equal ~printer:string_of_int before (count_red lvl)

(* ====================================================================== *)
(* Test registration                                                      *)
(* ====================================================================== *)

let tests =
  "Fireboy & Watergirl test suite"
  >::: [
         (* Level *)
         "tile_of_char known" >:: test_tile_of_char;
         "tile_of_char unknown" >:: test_tile_of_char_unknown;
         "from_string_list dims" >:: test_dimensions;
         "from_string_list widths" >:: test_inconsistent_widths;
         "from_string_list empty" >:: test_from_empty_list;
         (* Level_loader *)
         "loader dimensions" >:: test_loader_dimensions;
         "loader tiles" >:: test_loader_tiles;
         "loader tile_of_name" >:: test_loader_tile_of_name;
         "loader unknown tile name" >:: test_loader_unknown_tile_name;
         "loader bad row width" >:: test_loader_bad_row_width;
         "loader char not in legend" >:: test_loader_char_not_in_legend;
         "get in bounds" >:: test_get;
         "get out of bounds = Wall" >:: test_get_out_of_bounds;
         "set in bounds" >:: test_set;
         "set out of bounds noop" >:: test_set_out_of_bounds_is_noop;
         "copy independence" >:: test_copy;
         "is_solid" >:: test_is_solid;
         (* Sprite *)
         "image_rows indexing" >:: test_image_rows;
         "scale_rgba identity" >:: test_scale_rgba_identity;
         "scale_rgba upscales" >:: test_scale_rgba_upscale;
         "scale_rgba zero size" >:: test_scale_rgba_zero;
         "scale_rgba zero height" >:: test_scale_rgba_zero_height;
         "scale_rgba zero src width" >:: test_scale_rgba_zero_src_width;
         "scale_rgba zero src height" >:: test_scale_rgba_zero_src_height;
         "flip_rows_horizontally" >:: test_flip_rows_horizontally;
         (* Physics *)
         "physics move right" >:: test_physics_move_right;
         "physics move left" >:: test_physics_move_left;
         "physics friction positive" >:: test_physics_friction_positive;
         "physics friction negative" >:: test_physics_friction_negative;
         "physics friction zero" >:: test_physics_friction_zero;
         "physics airborne keeps vx" >:: test_physics_airborne_keeps_vx;
         "physics jump" >:: test_physics_jump;
         "physics right wall" >:: test_physics_right_wall;
         "physics left wall" >:: test_physics_left_wall;
         "physics floor landing" >:: test_physics_floor_landing;
         "physics ceiling hit" >:: test_physics_ceiling_hit;
         (* Game *)
         "init status Playing" >:: test_init_status;
         "init counters zero" >:: test_init_zero_counters;
         "init players alive" >:: test_init_players_alive;
         "init characters set" >:: test_init_player_characters;
         "Won is sticky" >:: test_won_status_is_sticky;
         "Won freezes elapsed" >:: test_won_freezes_elapsed;
         "Resetting counts down" >:: test_resetting_counts_down;
         "Resetting -> Playing" >:: test_resetting_to_playing;
         "Resetting clears elapsed" >:: test_resetting_clears_elapsed;
         "tick advances elapsed" >:: test_tick_advances_elapsed;
         "init copies the level" >:: test_init_does_not_mutate_input;
         "check_death fb in water" >:: test_check_death_fireboy_water;
         "check_death wg in fire" >:: test_check_death_watergirl_fire;
         "check_death in acid" >:: test_check_death_acid;
         "check_death safe" >:: test_check_death_safe;
         "check_win true" >:: test_check_win_true;
         "check_win false" >:: test_check_win_false;
         "collect diamonds fireboy" >:: test_collect_diamonds_fireboy;
         "collect diamonds watergirl" >:: test_collect_diamonds_watergirl;
         "collect diamonds none" >:: test_collect_diamonds_none;
         "tile_to_pixel_center" >:: test_tile_to_pixel_center;
         "fireboy_spawn_of found" >:: test_fireboy_spawn_of;
         "fireboy_spawn_of no tile" >:: test_fireboy_spawn_no_tile;
         "fireboy_spawn_of two tiles" >:: test_fireboy_spawn_two_tiles;
         "spawn_fireboy fields" >:: test_spawn_fireboy;
         "spawn_watergirl fields" >:: test_spawn_watergirl;
         "tick player death" >:: test_tick_player_death;
         "tick watergirl death" >:: test_tick_watergirl_death;
         "tick win condition" >:: test_tick_win_condition;
       ]

let _ = run_test_tt_main tests
