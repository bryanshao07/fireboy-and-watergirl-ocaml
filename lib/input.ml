type keys = {
  left : bool;
  right : bool;
  jump_pressed : bool;
}

external key_down : char -> bool = "teamproject_key_down"

type snapshot = {
  left : bool;
  right : bool;
  jump : bool;
  quit : bool;
  space : bool;
  restart : bool;
}

let empty = { left = false; right = false; jump = false; quit = false; space = false; restart = false }

let current = ref empty
let previous = ref empty
let current_wg = ref empty
let previous_wg = ref empty

let sample () =
  {
    left = key_down 'j';
    right = key_down 'l';
    jump = key_down 'i';
    quit = key_down 'q';
    space = key_down ' ';
    restart = key_down 'r';
  }

let sample_wg () =
  {
    left = key_down 'a';
    right = key_down 'd';
    jump = key_down 'w';
    quit = key_down 'q';
    space = key_down ' ';
    restart = key_down 'r';
  }

let drain () =
  previous := !current;
  previous_wg := !current_wg;
  while Graphics.key_pressed () do
    ignore (Graphics.read_key ())
  done;
  current := sample ();
  current_wg := sample_wg ()

let is_held k =
  match k with
  | 'j' -> !current.left
  | 'l' -> !current.right
  | 'i' -> !current.jump
  | 'q' -> !current.quit
  | ' ' -> !current.space
  | 'r' -> !current.restart
  | _ -> false

let poll_fireboy () =
  {
    left = !current.left;
    right = !current.right;
    jump_pressed = !current.jump && not !previous.jump;
  }

let poll_watergirl () =
  {
    left = !current_wg.left;
    right = !current_wg.right;
    jump_pressed = !current_wg.jump && not !previous_wg.jump;
  }

(* True on the first frame any "confirm" key is pressed: space, i (fb jump), or w (wg jump) *)
let confirm_just_pressed () =
  (!current.space && not !previous.space)
  || (!current.jump && not !previous.jump)
  || (!current_wg.jump && not !previous_wg.jump)
