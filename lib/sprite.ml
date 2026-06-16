type anim = {
  frames : Graphics.image array;
  frame_time : float;
}

type rgba_pixel = {
  r : int;
  g : int;
  b : int;
  a : int;
}

type rgba_image = {
  width : int;
  height : int;
  pixels : rgba_pixel array array;
}

let image_rows width height pixel_at =
  Array.init height (fun y -> Array.init width (fun x -> pixel_at x y))

let flip_rows_horizontally rows =
  Array.map
    (fun row ->
      let w = Array.length row in
      Array.init w (fun x -> row.(w - 1 - x)))
    rows

[@@@coverage off]

let flip_image_horizontally img =
  Graphics.dump_image img |> flip_rows_horizontally |> Graphics.make_image

[@@@coverage on]

let scale_rgba img width height =
  if width = img.width && height = img.height then img
  else if width <= 0 || height <= 0 || img.width = 0 || img.height = 0 then img
  else
    {
      width;
      height;
      pixels =
        image_rows width height (fun x y ->
            let source_x = x * img.width / width in
            let source_y = y * img.height / height in
            img.pixels.(source_y).(source_x));
    }

[@@@coverage off]

let scale_image img width height =
  let source = Graphics.dump_image img in
  let source_h = Array.length source in
  let source_w = if source_h = 0 then 0 else Array.length source.(0) in
  if width = source_w && height = source_h then img
  else if width <= 0 || height <= 0 || source_w = 0 || source_h = 0 then img
  else
    image_rows width height (fun x y ->
        let source_x = x * source_w / width in
        let source_y = y * source_h / height in
        source.(source_y).(source_x))
    |> Graphics.make_image

let load_png path =
  let img = ImageLib_unix.openfile path in
  let w = img.Image.width and h = img.Image.height in
  let arr =
    image_rows w h (fun x y ->
        Image.read_rgba img x y (fun r g b a ->
            if a < 128 then Graphics.transp else Graphics.rgb r g b))
  in
  Graphics.make_image arr

let load_png_rgba path =
  let img = ImageLib_unix.openfile path in
  let width = img.Image.width and height = img.Image.height in
  {
    width;
    height;
    pixels =
      image_rows width height (fun x y ->
          Image.read_rgba img x y (fun r g b a -> { r; g; b; a }));
  }

let load_anim paths fps =
  { frames = Array.of_list (List.map load_png paths); frame_time = 1.0 /. fps }

let frame_of anim timer =
  let n = Array.length anim.frames in
  anim.frames.(int_of_float (timer /. anim.frame_time) mod n)
