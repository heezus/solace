extends SceneTree
## Native layout regression: pinned actions and scroll access at narrow/default/wide widths.

const BuildBar = preload("res://scripts/build_bar.gd")
const Sim = preload("res://scripts/sim.gd")
const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func settle() -> void:
	for frame in range(6):
		await process_frame


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func run() -> void:
	Ui.apply_theme()
	var state := Sim.new()
	state.generate(42)
	for id in Data.TECHS:
		state.tech_tree.researched[id] = true
	for id in Data.ITEM_ORDER:
		state.economy.seen[id] = true
	var bar := BuildBar.new()
	root.add_child(bar)
	bar.setup(state)
	bar.refresh("", 3)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	for width in [800, 1100, 1280, 1600]:
		root.size = Vector2i(width, 800)
		await settle()
		for tab in Data.BUILD_TABS:
			bar._show_tab(tab)
			await settle()
			check(
				bar.get_global_rect().end.x <= width + 1,
				"%d/%s: bar extends past window %s" % [width, tab, bar.get_global_rect()]
			)
			for action in [bar.tech_button, bar.demolish_button] + bar.craft_buttons.values():
				var box: Rect2 = action.get_global_rect()
				check(
					box.position.x >= 0 and box.end.x <= width + 1,
					"%d/%s: action clipped: %s" % [width, tab, action.text]
				)
			for type in bar.build_buttons:
				var card: Button = bar.build_buttons[type]["button"]
				if not card.visible:
					continue
				bar.build_scroll.ensure_control_visible(card)
				await settle()
				var box := card.get_global_rect()
				var viewport := bar.build_scroll.get_global_rect()
				check(viewport.encloses(box), "%d/%s: cannot scroll full card into view: %s" % [width, tab, type])
				check(card.size.x >= BuildBar.BUTTON.x, "Readable card width preserved")
		if width == 1280:
			root.size = Vector2i(1280, 160)
			bar._show_tab("Logistics")
			bar.build_scroll.scroll_horizontal = 0
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/art/growth-visuals/build-bar-1280.png")
	var crafts: Array[String] = []
	bar.craft_picked.connect(func(recipe): crafts.append(recipe))
	for recipe in bar.craft_buttons:
		bar.craft_buttons[recipe].pressed.emit()
	check(crafts.size() == Data.RECIPES.size(), "Every craft button retains its recipe action")
	print("Build-bar fit: ", failures.size(), " failures; widths 800/1100/1280/1600; all tabs and craft actions")
	for failure in failures:
		print(failure)
	quit(0 if failures.is_empty() else 1)
