type character =
  | Fireboy
  | Watergirl

type player = {
  x : float;
  y : float;
  vx : float;
  vy : float;
  on_ground : bool;
  character : character;
  alive : bool;
  anim_timer : float;
}

let player_height = 45.
let player_width = 30.
