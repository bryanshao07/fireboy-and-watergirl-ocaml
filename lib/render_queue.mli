(** A queue of deferred draw calls. *)

(** A thunk that performs some drawing when invoked. *)
type draw_call = unit -> unit

(** Empty the queue. *)
val clear : unit -> unit

(** Enqueue a draw call. *)
val add : draw_call -> unit

(** Run every queued draw call in insertion order. *)
val flush : unit -> unit