(** Keyboard input polling.

    This module wraps the X11 keyboard via the [teamproject_key_down] C stub
    and tracks a per-frame snapshot for both Fireboy and Watergirl, so that
    "just pressed this frame" events (like jumps) can be distinguished from
    "still held". *)

(** A high-level summary of one player's controls for a single frame.
    [jump_pressed] is edge-triggered: it is [true] only on the frame where
    the jump key transitioned from up to down. *)
type keys = {
  left : bool;
  right : bool;
  jump_pressed : bool;
}

(** [key_down c] is [true] iff the key whose KeySym is [c] is currently down.
    This is the raw external call used internally; most callers should use
    [is_held], [poll_fireboy], [poll_watergirl], or [confirm_just_pressed]
    instead. *)
external key_down : char -> bool = "teamproject_key_down"

(** [drain ()] polls the keyboard once and updates the internal "current" and
    "previous" snapshots for both players. It must be called exactly once per
    frame, before any of the [poll_*]/[is_held]/[confirm_just_pressed]
    queries, so that edge-triggered events happen correctly. *)
val drain : unit -> unit

(** [is_held c] is [true] iff the key bound to character [c] is currently
    held down, as of the most recent [drain ()].
    Recognized keys: ['j'], ['l'], ['i'], ['q'], [' ']. Any other character
    returns [false]. *)
val is_held : char -> bool

(** [poll_fireboy ()] is Fireboy's controls for this frame, derived from the
    most recent [drain ()]. Maps J/L to left/right and edge-triggered I to
    [jump_pressed]. *)
val poll_fireboy : unit -> keys

(** [poll_watergirl ()] is Watergirl's controls for this frame, derived from
    the most recent [drain ()]. Maps A/D to left/right and edge-triggered W
    to [jump_pressed]. *)
val poll_watergirl : unit -> keys

(** [confirm_just_pressed ()] is [true] on the single frame when any
    "confirm" key (space, Fireboy's jump I, or Watergirl's jump W) has just
    transitioned from up to down. Used to advance from the intro screen and
    to restart from the win screen. *)
val confirm_just_pressed : unit -> bool