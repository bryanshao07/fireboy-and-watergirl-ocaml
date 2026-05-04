type anim = {
  frames : Graphics.image array;
  frame_time : float;
}

let image_rows width height pixel_at =
  Array.init height (fun y -> Array.init width (fun x -> pixel_at x y))

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
  let img = Png.load path [] in
  match img with
  | Images.Rgba32 rgba ->
      let w = rgba.Rgba32.width and h = rgba.Rgba32.height in
      let arr =
        image_rows w h (fun x y ->
            let c = Rgba32.get rgba x y in
            if c.Color.alpha < 128 then Graphics.transp
            else
              let rgb = c.Color.color in
              Graphics.rgb rgb.Color.r rgb.Color.g rgb.Color.b)
      in
      Graphics.make_image arr
  | Images.Rgb24 rgb ->
      let w = rgb.Rgb24.width and h = rgb.Rgb24.height in
      let arr =
        image_rows w h (fun x y ->
            let c = Rgb24.get rgb x y in
            Graphics.rgb c.Color.r c.Color.g c.Color.b)
      in
      Graphics.make_image arr
  | _ -> failwith "unsupported image format"

let load_anim paths fps =
  { frames = Array.of_list (List.map load_png paths); frame_time = 1.0 /. fps }

let frame_of anim timer =
  let n = Array.length anim.frames in
  anim.frames.(int_of_float (timer /. anim.frame_time) mod n)
