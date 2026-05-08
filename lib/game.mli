(** Top-level game state and main update/render loop. *)

(** Whether the game is being played, resetting after a death, or won.
    [Resetting remaining] holds seconds left until the level reinitializes. *)
type status =
  | Playing
  | Resetting of float
  | Won

(** A snapshot of the entire game.
    [level] is the current playing copy (which may have gems removed as
    they're collected). [original_level] is the unmodified level used to
    re-initialize after a death. *)
type t = {
  fireboy : Player.player;
  watergirl : Player.player;
  level : Level.t;
  original_level : Level.t;
  status : status;
  elapsed : float;
  red_gems : int;
  blue_gems : int;
}

(** Fresh game on a copy of [lvl], with both players at their spawns. *)
val init : Level.t -> t

(** Advance the game by [dt] seconds, given each player's input. *)
val tick : float -> t -> Input.keys -> Input.keys -> t

(** Draw one full frame: background, level, players, hazards, vignette, HUD. *)
val render : t -> unit