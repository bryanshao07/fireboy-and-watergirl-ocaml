(** Physics: gravity, friction, jumps, and tile collision. *)

(** Advance a player by [dt] seconds against [level], with input [keys]. *)
val update : float -> Level.t -> Player.player -> Input.keys -> Player.player