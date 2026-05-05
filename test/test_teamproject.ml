open OUnit2
open Teamproject

let no_keys = { Input.left = false; right = false; jump_pressed = false }

let only_water = Level.from_string_list [
  "###";
  "#W#";
  "###";
]

let only_fire = Level.from_string_list [
  "###";
  "#F#";
  "###";
]

let only_acid = Level.from_string_list [
  "###";
  "#A#";
  "###";
]

let spawn_level = Level.from_string_list [
  "###";
  "#1#";
  "###";
]

let pixel_at lvl tx ty = Game.tile_to_pixel_center tx ty lvl

let test_spawn_fireboy _ =
  let p = Game.spawn_fireboy (50., 75.) in
  assert_equal 50. p.Player.x ~printer:string_of_float;
  assert_equal 75. p.Player.y ~printer:string_of_float;
  assert_bool "should be alive" p.Player.alive;
  assert_equal Player.Fireboy p.Player.character

let test_spawn_watergirl _ =
  let p = Game.spawn_watergirl (0., 0.) in
  assert_equal Player.Watergirl p.Player.character;
  assert_bool "should be alive" p.Player.alive

let test_init _ =
  let g = Game.init Level.sample_level in
  assert_equal Game.Playing g.Game.status;
  assert_bool "fireboy alive" g.Game.fireboy.Player.alive;
  assert_bool "watergirl alive" g.Game.watergirl.Player.alive

let test_fireboy_spawn_uses_player_lower_left _ =
  let x, y = Game.fireboy_spawn_of spawn_level in
  let expected_x = 30. +. ((30. -. Player.player_width) /. 2.) in
  assert_equal expected_x x ~printer:string_of_float;
  assert_equal 30. y ~printer:string_of_float

let test_fireboy_dies_in_water _ =
  let (px, py) = pixel_at only_water 1 1 in
  let p = Game.spawn_fireboy (px, py) in
  let p' = Game.check_death p only_water in
  assert_bool "fireboy should die in water" (not p'.Player.alive)

let test_watergirl_survives_water _ =
  let (px, py) = pixel_at only_water 1 1 in
  let p = Game.spawn_watergirl (px, py) in
  let p' = Game.check_death p only_water in
  assert_bool "watergirl should survive water" p'.Player.alive

let test_watergirl_dies_in_fire _ =
  let (px, py) = pixel_at only_fire 1 1 in
  let p = Game.spawn_watergirl (px, py) in
  let p' = Game.check_death p only_fire in
  assert_bool "watergirl should die in fire" (not p'.Player.alive)

let test_fireboy_survives_fire _ =
  let (px, py) = pixel_at only_fire 1 1 in
  let p = Game.spawn_fireboy (px, py) in
  let p' = Game.check_death p only_fire in
  assert_bool "fireboy should survive fire" p'.Player.alive

let test_both_die_in_acid _ =
  let (px, py) = pixel_at only_acid 1 1 in
  let fb = Game.spawn_fireboy (px, py) in
  let wg = Game.spawn_watergirl (px, py) in
  let fb' = Game.check_death fb only_acid in
  let wg' = Game.check_death wg only_acid in
  assert_bool "fireboy should die in acid" (not fb'.Player.alive);
  assert_bool "watergirl should die in acid" (not wg'.Player.alive)

let test_resetting_counts_down _ =
  let g = { (Game.init Level.sample_level) with
            Game.status = Game.Resetting 1.0 } in
  let g' = Game.tick 0.3 g no_keys no_keys in
  (match g'.Game.status with
   | Game.Resetting r ->
       assert_bool (Printf.sprintf "timer should be < 1.0, got %f" r) (r < 1.0)
   | _ -> assert_failure "should still be resetting")

let test_resetting_triggers_respawn _ =
  let g = { (Game.init Level.sample_level) with
            Game.status = Game.Resetting 0.1 } in
  let g' = Game.tick 0.2 g no_keys no_keys in
  assert_equal Game.Playing g'.Game.status;
  assert_bool "fireboy alive after respawn" g'.Game.fireboy.Player.alive;
  assert_bool "watergirl alive after respawn" g'.Game.watergirl.Player.alive

let test_sprite_rows_keep_png_order _ =
  let rows = Sprite.image_rows 2 2 (fun x y -> (y * 10) + x) in
  assert_equal [| [| 0; 1 |]; [| 10; 11 |] |] rows

let test_sprite_rows_flip_horizontally _ =
  let rows = [| [| 1; 2; 3 |]; [| 4; 5; 6 |] |] in
  assert_equal [| [| 3; 2; 1 |]; [| 6; 5; 4 |] |]
    (Sprite.flip_rows_horizontally rows)

let test_player_rect_uses_lower_left_and_scaled_size _ =
  let rp : Render.render_params = { rts = 60; offset_x = 10; offset_y = 20 } in
  let p = Game.spawn_fireboy (35., 30.) in
  let rect = Render.player_rect rp p in
  assert_equal 80 rect.sx ~printer:string_of_int;
  assert_equal 80 rect.sy ~printer:string_of_int;
  assert_equal (Render.scaled_length rp Player.player_width) rect.sw
    ~printer:string_of_int;
  assert_equal (Render.scaled_length rp Player.player_height) rect.sh
    ~printer:string_of_int

let test_water_tile_uses_animation_sprites _ =
  assert_equal
    [ "data/water0.png"; "data/water1.png" ]
    (Render.sprite_paths_of_tile Level.Water)

let test_lava_tile_uses_animation_sprites _ =
  assert_equal
    [ "data/lava0.png"; "data/lava1.png" ]
    (Render.sprite_paths_of_tile Level.Fire)

let test_acid_tile_uses_animation_sprites _ =
  assert_equal
    [ "data/acid0.png"; "data/acid1.png" ]
    (Render.sprite_paths_of_tile Level.Acid)

let test_gem_tiles_use_sprites _ =
  assert_equal [ "data/fire_gem.png" ]
    (Render.sprite_paths_of_tile Level.DiamondFire);
  assert_equal [ "data/water_gem.png" ]
    (Render.sprite_paths_of_tile Level.DiamondWater)

let test_exit_tiles_use_sprites _ =
  assert_equal [ "data/fire_exit.png" ]
    (Render.sprite_paths_of_tile Level.ExitFire);
  assert_equal [ "data/water_exit.png" ]
    (Render.sprite_paths_of_tile Level.ExitWater)

let test_fireboy_walk_uses_walk_sprites _ =
  assert_equal
    [ "data/fb_walk0.png"; "data/fb_walk1.png"; "data/fb_walk2.png" ]
    Render.fireboy_walk_paths

let test_hazard_tiles_draw_over_players _ =
  assert_bool "water draws over players" (Render.draws_over_player Level.Water);
  assert_bool "fire draws over players" (Render.draws_over_player Level.Fire);
  assert_bool "acid draws over players" (Render.draws_over_player Level.Acid);
  assert_bool "wall stays behind players" (not (Render.draws_over_player Level.Wall))

let tests =
  "test suite" >::: [
    "spawn fireboy"              >:: test_spawn_fireboy;
    "spawn watergirl"            >:: test_spawn_watergirl;
    "init"                       >:: test_init;
    "fireboy spawn lower-left"   >:: test_fireboy_spawn_uses_player_lower_left;
    "fireboy dies in water"      >:: test_fireboy_dies_in_water;
    "watergirl survives water"   >:: test_watergirl_survives_water;
    "watergirl dies in fire"     >:: test_watergirl_dies_in_fire;
    "fireboy survives fire"      >:: test_fireboy_survives_fire;
    "both die in acid"           >:: test_both_die_in_acid;
    "resetting counts down"      >:: test_resetting_counts_down;
    "resetting triggers respawn" >:: test_resetting_triggers_respawn;
    "sprite rows keep png order" >:: test_sprite_rows_keep_png_order;
    "sprite rows flip"           >:: test_sprite_rows_flip_horizontally;
    "player rect scales"         >:: test_player_rect_uses_lower_left_and_scaled_size;
    "water tile uses sprites"    >:: test_water_tile_uses_animation_sprites;
    "lava tile uses sprites"     >:: test_lava_tile_uses_animation_sprites;
    "acid tile uses sprites"     >:: test_acid_tile_uses_animation_sprites;
    "gem tiles use sprites"      >:: test_gem_tiles_use_sprites;
    "exit tiles use sprites"     >:: test_exit_tiles_use_sprites;
    "fireboy walk uses sprites"  >:: test_fireboy_walk_uses_walk_sprites;
    "hazards draw over players"  >:: test_hazard_tiles_draw_over_players;
  ]

let _ = run_test_tt_main tests
