class_name Minimap
extends Control
## Minikarte oben rechts; Taste M schaltet auf die große Karte über dem ganzen Bild.
## Daten: EventBus.level_loaded(layout) (AP6), Bild über MinimapData.build_image(), dazu exits,
## entrance und markers aus dem Layout.
## Aufgedeckt wird, was der Spieler (Game.player) gesehen hat. Die Karte ist so gedreht, dass oben
## dort ist, wohin die Kamera schaut.

const SMALL_SIZE := Vector2(260, 260)
## Pixel pro Meter auf der kleinen Karte.
const SMALL_SCALE := 2.4
## Sichtweite in Metern: so weit deckt der Spieler die Karte auf.
const REVEAL_RADIUS := 14.0
const REVEAL_INTERVAL := 0.2
## Wände heller als in MinimapData, damit Raumumrisse auf dunklem Grund gut zu sehen sind.
const WALL_COLOR := Color(0.8, 0.7, 0.52, 1.0)
const MARKER_COLORS: Dictionary[StringName, Color] = {
	&"merchant": Color(1.0, 0.8, 0.3),
	&"stash": Color(0.7, 0.55, 0.35),
	&"portal": Color(0.35, 0.6, 1.0),
	&"boss_spawn": Color(0.95, 0.2, 0.15),
	&"boss_chest": Color(1.0, 0.6, 0.2),
}

var layout: LevelLayout
## Große Karte (M) statt Minikarte.
var big: bool = false:
	set = set_big
## Vollständige Karte, 1 Pixel pro Zelle.
var full_image: Image
## Aufgedeckter Teil, wird gezeichnet.
var shown_image: Image
var texture: ImageTexture
var revealed_count: int = 0

var _reveal_timer: float = 0.0
var _dirty: bool = false


func _init() -> void:
	name = "Minimap"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_placement()
	EventBus.level_loaded.connect(set_layout)


func set_big(value: bool) -> void:
	big = value
	_apply_placement()
	queue_redraw()


func set_layout(p_layout: LevelLayout) -> void:
	layout = p_layout
	revealed_count = 0
	full_image = null
	shown_image = null
	texture = null
	if layout == null or layout.cells.is_empty():
		queue_redraw()
		return
	# Bild und Farben liefert AP6 (world/minimap_data.gd); Wände hellen wir für die Lesbarkeit auf.
	full_image = MinimapData.build_image(layout)
	for x in full_image.get_width():
		for y in full_image.get_height():
			if full_image.get_pixel(x, y) == MinimapData.COLOR_WALL:
				full_image.set_pixel(x, y, WALL_COLOR)
	shown_image = Image.create_empty(
		full_image.get_width(), full_image.get_height(), false, Image.FORMAT_RGBA8
	)
	if Game.player != null and is_instance_valid(Game.player) and Game.player.is_inside_tree():
		reveal_around(Game.player.global_position)
	texture = ImageTexture.create_from_image(shown_image)
	_dirty = false
	queue_redraw()


## Deckt die Karte im Umkreis radius (Meter) um einen Weltpunkt auf.
func reveal_around(world: Vector3, radius: float = REVEAL_RADIUS) -> void:
	if full_image == null:
		return
	var center := world_to_pixel(world)
	var cells_radius := radius / maxf(layout.cell_size.x, 0.01)
	var r := ceili(cells_radius)
	for x in range(floori(center.x) - r, floori(center.x) + r + 1):
		for y in range(floori(center.y) - r, floori(center.y) + r + 1):
			if x < 0 or y < 0 or x >= full_image.get_width() or y >= full_image.get_height():
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(center) > cells_radius:
				continue
			var color := full_image.get_pixel(x, y)
			if color.a > 0.0 and shown_image.get_pixel(x, y).a == 0.0:
				shown_image.set_pixel(x, y, color)
				revealed_count += 1
				_dirty = true


## Deckt alles auf (zum Beispiel für den Bossraum oder Tests).
func reveal_all() -> void:
	if full_image == null:
		return
	shown_image.copy_from(full_image)
	revealed_count = 0
	for x in full_image.get_width():
		for y in full_image.get_height():
			if full_image.get_pixel(x, y).a > 0.0:
				revealed_count += 1
	_dirty = true


## Weltpunkt → Bildkoordinate (Pixel, eine Zelle = ein Pixel), wie MinimapData (AP6).
func world_to_pixel(world: Vector3) -> Vector2:
	if layout == null:
		return Vector2.ZERO
	return MinimapData.world_to_pixel(layout, world)


func _process(delta: float) -> void:
	if layout == null:
		return
	_reveal_timer -= delta
	if _reveal_timer <= 0.0:
		_reveal_timer = REVEAL_INTERVAL
		if Game.player != null and is_instance_valid(Game.player) and Game.player.is_inside_tree():
			reveal_around(Game.player.global_position)
	if _dirty and texture != null:
		texture.update(shown_image)
		_dirty = false
	queue_redraw()


func _apply_placement() -> void:
	if big:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		offset_left = 160
		offset_right = -160
		offset_top = 90
		offset_bottom = -220
	else:
		set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -SMALL_SIZE.x - 20
		offset_right = -20
		offset_top = 20
		offset_bottom = 20 + SMALL_SIZE.y


func _map_rotation() -> float:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return 0.0
	var forward := -camera.global_basis.z
	if Vector2(forward.x, forward.z).length() < 0.01:
		return 0.0
	return -PI * 0.5 - atan2(forward.z, forward.x)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.02, 0.02, 0.025, 0.55 if big else 0.75))
	if texture != null and layout != null:
		var player_pixel := Vector2(texture.get_size()) * 0.5
		var has_player := Game.player != null and is_instance_valid(Game.player)
		if has_player and not big:
			player_pixel = world_to_pixel(Game.player.global_position)
		var pixel_scale := SMALL_SCALE * layout.cell_size.x
		if big:
			var tex_size := Vector2(texture.get_size())
			pixel_scale = minf(size.x / tex_size.x, size.y / tex_size.y) * 0.9
		var angle := _map_rotation()
		draw_set_transform(size * 0.5, angle, Vector2.ONE * pixel_scale)
		draw_texture(texture, -player_pixel)
		for exit in layout.exits:
			_draw_marker(
				world_to_pixel(exit) - player_pixel, Color(0.9, 0.25, 0.2), pixel_scale, true
			)
		if layout.entrance != Vector3.INF:
			_draw_marker(
				world_to_pixel(layout.entrance) - player_pixel,
				Color(0.5, 0.8, 0.5),
				pixel_scale,
				false
			)
		for key: StringName in layout.markers:
			var color: Color = MARKER_COLORS.get(key, UiTheme.TEXT)
			var p := world_to_pixel(layout.markers[key]) - player_pixel
			draw_circle(p, 4.5 / pixel_scale, color)
		if has_player:
			var p := world_to_pixel(Game.player.global_position) - player_pixel
			var facing := -Game.player.global_basis.z
			var dir := Vector2(facing.x, facing.z).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.UP
			var s := 7.0 / pixel_scale
			var tri := PackedVector2Array(
				[p + dir * s * 1.4, p + dir.rotated(2.5) * s, p + dir.rotated(-2.5) * s]
			)
			draw_colored_polygon(tri, Color(1.0, 0.95, 0.8))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_string(
			get_theme_default_font(),
			Vector2(0, size.y * 0.5),
			"Keine Karte",
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			UiTheme.FONT_SIZE_SMALL,
			UiTheme.TEXT_MUTED
		)
	draw_rect(rect, UiTheme.BORDER, false, 2.0)
	if big:
		draw_string(
			get_theme_default_font(),
			Vector2(16, 30),
			"Karte (M schließt)",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			UiTheme.FONT_SIZE_TITLE,
			UiTheme.TEXT_TITLE
		)


func _draw_marker(p: Vector2, color: Color, pixel_scale: float, down: bool) -> void:
	var s := 6.0 / pixel_scale
	var tip := Vector2(0, s) if down else Vector2(0, -s)
	var tri := PackedVector2Array(
		[p + tip, p + Vector2(-s, -tip.y * 0.8), p + Vector2(s, -tip.y * 0.8)]
	)
	draw_colored_polygon(tri, color)
