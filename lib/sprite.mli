(** Image and animation loading, scaling, and frame selection. *)

(** A looping animation. *)
type anim = {
  frames : Graphics.image array;
  frame_time : float;
}

(** A single RGBA pixel; each channel in [0..255]. *)
type rgba_pixel = {
  r : int;
  g : int;
  b : int;
  a : int;
}

(** A full RGBA image. Indexed [pixels.(y).(x)]. *)
type rgba_image = {
  width : int;
  height : int;
  pixels : rgba_pixel array array;
}

(** Build an [h]-by-[w] 2D array by calling [pixel_at x y] for each cell. *)
val image_rows : int -> int -> (int -> int -> 'a) -> 'a array array

(** Mirror each row of a 2D array left-to-right. *)
val flip_rows_horizontally : 'a array array -> 'a array array

(** Mirror an image left-to-right. *)
val flip_image_horizontally : Graphics.image -> Graphics.image

(** Nearest-neighbor scale to [w]-by-[h]. *)
val scale_rgba : rgba_image -> int -> int -> rgba_image

(** Nearest-neighbor scale to [w]-by-[h]. *)
val scale_image : Graphics.image -> int -> int -> Graphics.image

(** Load a PNG. Pixels with alpha < 128 become transparent.
    Raises [Failure "unsupported image format"] for non-RGBA32/RGB24 PNGs. *)
val load_png : string -> Graphics.image

(** Load a PNG preserving alpha for later compositing. *)
val load_png_rgba : string -> rgba_image

(** Load each PNG as a frame; play at [fps] frames per second. *)
val load_anim : string list -> float -> anim

(** Frame to show at elapsed time [timer] seconds. Loops. *)
val frame_of : anim -> float -> Graphics.image