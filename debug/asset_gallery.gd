extends Node3D
## Testszene für AP8: alle Figuren mit ihren Animationen in einem Raum aus dem Baukasten,
## dazu eine Übersicht aller 40 Baukasten-Teile.
##
## Start: godot --path . -- --scene=asset_gallery      (Windows: SpielJBR.exe --scene=asset_gallery)
## Tasten: Leertaste nächste Animation · A automatisch weiter an/aus · 1 bis 5 Figur in den Fokus
##         Tab Raum oder Baukasten-Übersicht · L seltene, K legendäre Beute · Mausrad Zoom

const CHARACTERS: Array[String] = [
	"warrior", "skeleton_swarm", "ghoul", "skeleton_archer", "cultist_summoner"
]
## Reihenfolge der vorgeführten Animationen.
const SEQUENCE: Array[StringName] = [
	&"idle",
	&"walk",
	&"run",
	&"attack_1",
	&"attack_2",
	&"attack_3",
	&"attack_4",
	&"cast",
	&"block",
	&"hit",
	&"dodge",
	&"interact",
	&"spawn",
	&"death",
]
## Sekunden je Animation im Automatikbetrieb (Fortbewegung und Schleifen).
const STEP_SECONDS := 2.2
const ROOM_SIZE := Vector2i(6, 5)
const CELL := 4.0
const GALLERY_OFFSET := Vector3(80, 0, 0)
const GALLERY_COLUMNS := 8

var _figures: Array[CharacterModel] = []
var _labels: Array[Label3D] = []
var _step: int = 0
var _step_left: float = STEP_SECONDS
var _auto: bool = true
var _show_gallery: bool = false
var _focus: int = -1
var _zoom: float = 1.0
var _camera: Camera3D
var _info: Label


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_gallery()
	_spawn_figures()
	_build_ui()
	_play_step()


func _process(delta: float) -> void:
	if _auto:
		_step_left -= delta
		if _step_left <= 0.0 and not _any_busy():
			_next_step()
	_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.keycode:
			KEY_SPACE:
				_next_step()
			KEY_A:
				_auto = not _auto
			KEY_TAB:
				_show_gallery = not _show_gallery
			KEY_L:
				GameSounds.play_at(GameSounds.LOOT_DROP_RARE, _camera_target(), self)
			KEY_K:
				GameSounds.play_at(GameSounds.LOOT_DROP_LEGENDARY, _camera_target(), self)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				var index := key.keycode - KEY_1
				_focus = -1 if _focus == index else index
		_update_info()
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_zoom * 0.9, 0.35)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_zoom * 1.1, 2.5)


## Aktuelle Animation (für Tests und Anzeige).
func current_animation() -> StringName:
	return SEQUENCE[_step]


func figures() -> Array[CharacterModel]:
	return _figures


func _next_step() -> void:
	_step = (_step + 1) % SEQUENCE.size()
	_play_step()


func _play_step() -> void:
	var anim := SEQUENCE[_step]
	_step_left = STEP_SECONDS
	for index in _figures.size():
		var figure := _figures[index]
		if figure.is_dead():
			figure.revive()
		figure.stop_action()
		figure.set_move_velocity(0.0)
		match anim:
			&"idle":
				pass
			&"walk":
				figure.set_move_velocity(figure.walk_speed)
			&"run":
				figure.set_move_velocity(figure.run_speed)
			&"hit":
				figure.play_hit()
			&"death":
				figure.play_death()
			_:
				figure.play_action(anim)
		_labels[index].text = "%s\n%s" % [CHARACTERS[index], anim]
	_update_info()


func _any_busy() -> bool:
	for figure in _figures:
		# Schleifen (Wirbelsturm, Zielen) enden nur über die Zeit.
		if figure.is_busy() and _step_left > -3.0:
			return true
	return false


func _spawn_figures() -> void:
	for index in CHARACTERS.size():
		var scene := load("res://assets/characters/%s.tscn" % CHARACTERS[index]) as PackedScene
		var figure := scene.instantiate() as CharacterModel
		add_child(figure)
		figure.position = Vector3(4.0 + index * 4.0, 0.0, 13.0)
		figure.rotation.y = PI  # zur Kamera drehen
		_figures.append(figure)
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = figure.position + Vector3(0, 2.6, 0)
		label.font_size = 48
		label.pixel_size = 0.006
		label.outline_size = 12
		add_child(label)
		_labels.append(label)


func _build_room() -> void:
	var cells := _make_grid(&"Cells")
	var props := _make_grid(&"Props")
	var width := ROOM_SIZE.x
	var depth := ROOM_SIZE.y
	for x in width:
		for z in depth:
			var floor_id := WorldTiles.Id.FLOOR
			if (x + z * 3) % 7 == 0:
				floor_id = WorldTiles.Id.FLOOR_CRACKED
			_place(cells, Vector2i(x, z), floor_id, Vector2i(0, 1))
	# Rückwand (Blick zur Kamera), Seitenwände; die Vorderseite bleibt offen.
	for x in width:
		_place(cells, Vector2i(x, -1), WorldTiles.Id.WALL, Vector2i(0, 1))
	for z in depth:
		var left := WorldTiles.Id.DOORWAY if z == 2 else WorldTiles.Id.WALL
		_place(
			cells,
			Vector2i(-1, z),
			left,
			Vector2i(1, 0) if left == WorldTiles.Id.WALL else Vector2i(-1, 0)
		)
		_place(cells, Vector2i(width, z), WorldTiles.Id.WALL, Vector2i(-1, 0))
	_set_diagonal(cells, Vector2i(-1, -1), WorldTiles.Id.WALL_CORNER, Vector2i(1, 1))
	_set_diagonal(cells, Vector2i(width, -1), WorldTiles.Id.WALL_CORNER, Vector2i(-1, 1))
	_place(cells, Vector2i(1, 1), WorldTiles.Id.PILLAR, Vector2i(0, 1))
	_place(cells, Vector2i(4, 1), WorldTiles.Id.PILLAR, Vector2i(0, 1))
	# Requisiten an den Wänden (Wand liegt lokal bei -Z).
	_place(props, Vector2i(0, 0), WorldTiles.Id.PROP_COBWEB, Vector2i(0, 1))
	_place(props, Vector2i(2, 0), WorldTiles.Id.TORCH_WALL, Vector2i(0, 1))
	_place(props, Vector2i(3, 0), WorldTiles.Id.PROP_BANNER, Vector2i(0, 1))
	_place(props, Vector2i(4, 0), WorldTiles.Id.TORCH_WALL, Vector2i(0, 1))
	_place(props, Vector2i(5, 0), WorldTiles.Id.PROP_CHEST, Vector2i(0, 1))
	_place(props, Vector2i(0, 4), WorldTiles.Id.PROP_COFFIN, Vector2i(1, 0))
	_place(props, Vector2i(5, 4), WorldTiles.Id.PROP_BARREL, Vector2i(0, 1))
	_place(props, Vector2i(5, 3), WorldTiles.Id.PROP_CRATE, Vector2i(0, 1))
	_place(props, Vector2i(2, 1), WorldTiles.Id.PROP_BONES, Vector2i(0, 1))
	_place(props, Vector2i(3, 1), WorldTiles.Id.BRAZIER, Vector2i(0, 1))
	_place(props, Vector2i(0, 1), WorldTiles.Id.PROP_CANDLES, Vector2i(0, 1))
	_add_light(Vector3(2.5 * CELL, 2.6, 0.9), Color(1.0, 0.6, 0.3), 7.0)
	_add_light(Vector3(4.5 * CELL, 2.6, 0.9), Color(1.0, 0.6, 0.3), 7.0)
	_add_light(Vector3(3.5 * CELL, 1.5, 1.5 * CELL), Color(1.0, 0.5, 0.2), 9.0)


func _build_gallery() -> void:
	var kit := load(WorldKit.REAL_PATH) as MeshLibrary
	var ids := WorldTiles.NAMES.keys()
	for index in ids.size():
		var id: int = ids[index]
		var spot := (
			GALLERY_OFFSET
			+ Vector3(
				(index % GALLERY_COLUMNS) * 5.0, 0.0, floorf(index / float(GALLERY_COLUMNS)) * 6.0
			)
		)
		var mesh := MeshInstance3D.new()
		mesh.mesh = kit.get_item_mesh(kit.find_item_by_name(WorldTiles.NAMES[id]))
		mesh.position = spot
		add_child(mesh)
		var label := Label3D.new()
		label.text = "%d %s" % [id, WorldTiles.NAMES[id]]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = spot + Vector3(0, 4.6, 2.2)
		label.font_size = 40
		label.pixel_size = 0.008
		label.outline_size = 10
		add_child(label)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.37, 0.45)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.make_current()
	_update_camera(1.0)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	# Unten links, oben links liegt die Debug-Anzeige (F3).
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = 16.0
	_info.offset_top = -72.0
	_info.add_theme_font_size_override(&"font_size", 20)
	_info.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_info.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_info)
	_update_info()


func _update_info() -> void:
	if _info == null:
		return
	_info.text = (
		(
			"AP8 Asset-Galerie · Animation: %s (%d/%d) · Automatik: %s\n"
			% [SEQUENCE[_step], _step + 1, SEQUENCE.size(), "an" if _auto else "aus"]
		)
		+ "Leertaste weiter · A Automatik · 1-5 Figur · Tab Baukasten · L/K Beuteklang · Mausrad Zoom"
	)


func _camera_target() -> Vector3:
	if _show_gallery:
		return GALLERY_OFFSET + Vector3(17.5, 0, 12)
	if _focus >= 0:
		return _figures[_focus].global_position + Vector3(0, 0.9, 0)
	return Vector3(12, 0.5, 9)


func _update_camera(delta: float) -> void:
	var target := _camera_target()
	var distance := 7.0 if _focus >= 0 and not _show_gallery else 26.0
	if _show_gallery:
		distance = 42.0
	var offset := Vector3(0, 0.75, 1).normalized() * distance * _zoom
	var goal := Transform3D.IDENTITY.looking_at(-offset, Vector3.UP)
	goal.origin = target + offset
	_camera.transform = _camera.transform.interpolate_with(goal, clampf(delta * 6.0, 0.0, 1.0))


func _make_grid(grid_name: StringName) -> GridMap:
	var grid := GridMap.new()
	grid.name = grid_name
	grid.mesh_library = WorldKit.get_library()
	grid.cell_size = Vector3.ONE * CELL
	grid.cell_center_y = false
	add_child(grid)
	return grid


func _place(grid: GridMap, cell: Vector2i, tile: int, facing: Vector2i) -> void:
	var item := WorldKit.item_for(tile)
	grid.set_cell_item(Vector3i(cell.x, 0, cell.y), item, WorldTiles.orientation_facing(facing))


func _set_diagonal(grid: GridMap, cell: Vector2i, tile: int, diagonal: Vector2i) -> void:
	var orientation := WorldTiles.orientation_for_diagonal(diagonal)
	grid.set_cell_item(Vector3i(cell.x, 0, cell.y), WorldKit.item_for(tile), orientation)


func _add_light(at: Vector3, color: Color, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = 2.2
	light.omni_range = reach
	light.shadow_enabled = true
	add_child(light)
