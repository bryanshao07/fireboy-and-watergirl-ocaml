(** All on-screen drawing: HUD, intro, win screen, level tiles, and players. *)

(** Source-art tile size in pixels. Also used by [Physics] for collision. *)
val tile_size : int

(** How to project the world onto the window: [rts] is the rendered tile size,
    [(offset_x, offset_y)] centers the play area. *)
type render_params = {
  rts : int;
  offset_x : int;
  offset_y : int;
}

(** A rectangle in screen pixels. *)
type screen_rect = {
  sx : int;
  sy : int;
  sw : int;
  sh : int;
}

(** Compute the largest tile size that fits [lvl] in the current window. *)
val compute_render_params : Level.t -> render_params

(** Fill the window with the tiled background. Call first each frame. *)
val draw_background : render_params -> Level.t -> unit

(** Draw every non-empty tile, animating with [timer]. *)
val draw_level : render_params -> float -> Level.t -> unit

(** Redraw hazards (fire/water/acid) on top of players. Call after [draw_player]. *)
val draw_foreground_tiles : render_params -> float -> Level.t -> unit

(** Draw a player with idle/walk animation and horizontal flip. *)
val draw_player : render_params -> Player.player -> unit

(** Apply the darkened-edges overlay. Call near the end of the frame. *)
val draw_vignette : unit -> unit

(** [draw_hud time red_gems blue_gems] draws the in-game stats panel. *)
val draw_hud : float -> int -> int -> unit

(** Draw the title screen. *)
val draw_intro : unit -> unit

(** [draw_win time red_gems blue_gems] draws the level-complete screen. *)
val draw_win : float -> int -> int -> unit