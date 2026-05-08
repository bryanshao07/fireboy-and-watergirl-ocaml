(** Player character types and constants. *)

(** Which playable character. *)
type character =
  | Fireboy
  | Watergirl

(** State of a single player.
    [(x, y)] is the lower-left of the bounding box, with y increasing upward. *)
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

(** Bounding-box height in world pixels. *)
val player_height : float

(** Bounding-box width in world pixels. *)
val player_width : float