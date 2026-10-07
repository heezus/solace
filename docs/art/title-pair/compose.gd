extends SceneTree
## Documentation-only composition: original painting + independent foreground texture.
const HERE := "res://docs/art/title-pair/"
class Artwork extends Node2D:
 var background: Texture2D
 var foreground: Texture2D
 var canvas_size: Vector2
 var foreground_box: Rect2
 func _draw() -> void:
  draw_texture_rect(background, Rect2(Vector2.ZERO,canvas_size),false)
  draw_texture_rect(foreground,foreground_box,false)
func _init() -> void:
 call_deferred("compose")
func compose() -> void:
 var background_image := Image.new()
 if background_image.load(ProjectSettings.globalize_path(HERE + "original-background.png")) != OK:
  quit(1)
  return
 var raw_image := Image.new()
 if raw_image.load(ProjectSettings.globalize_path("res://art/rendered/title-pair-foreground.png")) != OK:
  quit(1)
  return
 var low := raw_image.get_size()
 var high := Vector2i(-1,-1)
 for y in raw_image.get_height():
  for x in raw_image.get_width():
   if raw_image.get_pixel(x,y).a > 0.05:
    low.x = mini(low.x,x)
    low.y = mini(low.y,y)
    high.x = maxi(high.x,x)
    high.y = maxi(high.y,y)
 var bounds := Rect2i(low,high-low+Vector2i.ONE).grow(2).intersection(Rect2i(Vector2i.ZERO,raw_image.get_size()))
 var atlas := AtlasTexture.new()
 atlas.atlas = ImageTexture.create_from_image(raw_image)
 atlas.region = bounds
 atlas.filter_clip = true
 var viewport := SubViewport.new()
 viewport.size = background_image.get_size()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var artwork := Artwork.new()
 artwork.background = ImageTexture.create_from_image(background_image)
 artwork.foreground = atlas
 artwork.canvas_size = viewport.size
 var height := viewport.size.y * 0.68
 var width := height * bounds.size.x / bounds.size.y
 artwork.foreground_box = Rect2(Vector2(viewport.size.x * 0.625,viewport.size.y-height),Vector2(width,height))
 viewport.add_child(artwork)
 for i in 6:
  await process_frame
 await RenderingServer.frame_post_draw
 var result := viewport.get_texture().get_image()
 var error := result.save_png("res://art/rendered/title_alt.png")
 var manifest := {"background":"original-background.png","foreground":"res://art/rendered/title-pair-foreground.png","foreground_region":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"foreground_box":[artwork.foreground_box.position.x,artwork.foreground_box.position.y,width,height],"canvas":[viewport.size.x,viewport.size.y],"method":"Godot two-layer render; original source textures unchanged"}
 var file := FileAccess.open(HERE+"layers.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"\t")+"\n")
 print("PAIR_CAPTURE saved=",error," region=",bounds," size=",viewport.size)
 quit(0 if error == OK else 1)
