class_name TitleScreen
extends Node3D
## Titelbildschirm (Startszene von SpielJBR.exe): der Gruftwächter zwischen zwei Feuerschalen,
## davor der Krieger. Knöpfe Neues Spiel, Weiter (nur mit Spielstand) und Beenden.
## Startet encounters/game.tscn über GameSession.launch_mode.

const GAME_SCENE := "res://encounters/game.tscn"
const WARRIOR_SCENE := "res://assets/characters/warrior.tscn"
const WARDEN_SCENE := "res://encounters/boss/crypt_warden_model.tscn"
const ENVIRONMENT := "res://graphics/environments/boss.tres"
const GAME_TITLE := "Spiel JBR"
const SUBTITLE := "Die Gruft des Wächters"
const CAMERA_SWAY := 0.35

var new_game_button: Button
var continue_button: Button
var quit_button: Button
var confirm_dialog: ConfirmationDialog
var music: MusicDirector
## Startet das Spiel (Standard: Szenenwechsel). Tests setzen hier eine eigene Funktion ein.
var launcher: Callable = func() -> void: Game.change_scene(GAME_SCENE)

var _camera: Camera3D
var _camera_origin: Vector3
var _time: float = 0.0
var _save_summary: String = ""


func _ready() -> void:
	get_tree().paused = false
	_build_backdrop()
	_build_menu()
	music = MusicDirector.new()
	music.name = "Music"
	music.follow_game = false
	add_child(music)
	music.play(&"catacombs")
	_refresh_save()


func _process(delta: float) -> void:
	_time += delta
	if _camera != null:
		_camera.position = _camera_origin + Vector3(sin(_time * 0.15) * CAMERA_SWAY, 0, 0)
		_camera.look_at(Vector3(0.6, 2.0, -2.5))


## Neues Spiel. Mit vorhandenem Spielstand erst nachfragen.
func start_new_game(confirmed: bool = false) -> void:
	if SaveService.has_save() and not confirmed:
		confirm_dialog.popup_centered()
		return
	_launch(GameSession.LaunchMode.NEW_GAME)


func continue_game() -> void:
	if not SaveService.has_save():
		return
	_launch(GameSession.LaunchMode.CONTINUE)


func quit_game() -> void:
	get_tree().quit()


func has_save() -> bool:
	return not _save_summary.is_empty()


func _launch(mode: GameSession.LaunchMode) -> void:
	GameSession.launch_mode = mode
	launcher.call()


func _refresh_save() -> void:
	_save_summary = ""
	if SaveService.has_save():
		var data := SaveGame.read()
		if not data.is_empty():
			_save_summary = SaveGame.summary(data)
	continue_button.disabled = _save_summary.is_empty()
	continue_button.tooltip_text = _save_summary
	var detail := continue_button.get_node(^"Detail") as Label
	detail.text = _save_summary if has_save() else "Kein Spielstand"
	(continue_button if has_save() else new_game_button).grab_focus.call_deferred()


# --- Kulisse -----------------------------------------------------------------------------------


func _build_backdrop() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	if ResourceLoader.exists(ENVIRONMENT):
		environment.environment = load(ENVIRONMENT) as Environment
	else:
		environment.environment = Level.default_environment(&"boss")
	add_child(environment)
	var layout := LevelLayout.new()
	layout.theme = &"boss"
	for x in range(-3, 3):
		for z in range(-3, 2):
			layout.cells[Vector3i(x, 0, z)] = WorldTiles.Id.FLOOR_BOSS
	for x in range(-3, 3):
		layout.cells[Vector3i(x, 0, -3)] = WorldTiles.Id.WALL
		layout.cell_orientations[Vector3i(x, 0, -3)] = WorldTiles.orientation_facing(Vector2i(0, 1))
	for cell: Vector3i in [Vector3i(-2, 0, -2), Vector3i(1, 0, -2)]:
		layout.props[cell] = WorldTiles.Id.BRAZIER
	for cell: Vector3i in [Vector3i(-3, 0, -1), Vector3i(2, 0, -1)]:
		layout.cells[cell] = WorldTiles.Id.PILLAR
	for cell: Vector3i in [Vector3i(-1, 0, -3), Vector3i(0, 0, -3)]:
		layout.props[cell] = WorldTiles.Id.PROP_BANNER
		layout.prop_orientations[cell] = WorldTiles.orientation_facing(Vector2i(0, 1))
	add_child(LevelBuilder.build_grid(layout, layout.cells, layout.cell_orientations, "Cells"))
	add_child(LevelBuilder.build_grid(layout, layout.props, layout.prop_orientations, "Props"))
	for spot: Vector3 in [Vector3(-6, 2.2, -6), Vector3(6, 2.2, -6)]:
		var light := LightPresets.make(LightPresets.Kind.BRAZIER)
		light.position = spot
		add_child(light)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.45, 0.6, 1.0)
	rim.light_energy = 1.2
	rim.omni_range = 14.0
	rim.position = Vector3(0, 5, 6)
	add_child(rim)
	var glow := SpotLight3D.new()
	glow.name = "WardenLight"
	glow.light_color = Color(1.0, 0.35, 0.2)
	glow.light_energy = 6.0
	glow.spot_range = 14.0
	glow.spot_angle = 24.0
	glow.position = Vector3(0.5, 6.5, 2.5)
	add_child(glow)
	glow.look_at(Vector3(0, 1.8, -3.5))
	var warden := _add_model(WARDEN_SCENE, Vector3(0, 0, -3.5), 0.0, 1.45)
	if warden != null:
		warden.name = "Warden"
	var warrior := _add_model(WARRIOR_SCENE, Vector3(2.6, 0, 0.6), 0.6, 1.0)
	if warrior != null:
		warrior.name = "Warrior"
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 45.0
	_camera_origin = Vector3(2.4, 2.8, 9.5)
	_camera.position = _camera_origin
	add_child(_camera)
	_camera.look_at(Vector3(0.6, 2.0, -2.5))
	_camera.current = true


func _add_model(path: String, at: Vector3, yaw: float, model_scale: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.position = at
	model.rotation.y = yaw
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	return model


# --- Menü --------------------------------------------------------------------------------------


func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Menu"
	add_child(layer)
	var root := Control.new()
	root.name = "Root"
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size.x = 520
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.name = "Buttons"
	box.add_theme_constant_override(&"separation", 14)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(80, -170)
	box.custom_minimum_size = Vector2(360, 0)
	root.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = GAME_TITLE
	title.add_theme_font_size_override(&"font_size", 64)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = SUBTITLE
	subtitle.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
	subtitle.add_theme_font_size_override(&"font_size", 22)
	box.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	box.add_child(gap)
	new_game_button = _button(box, "NewGameButton", "Neues Spiel")
	new_game_button.pressed.connect(start_new_game)
	continue_button = _button(box, "ContinueButton", "Weiter")
	continue_button.custom_minimum_size.y = 64
	var detail := Label.new()
	detail.name = "Detail"
	detail.add_theme_font_size_override(&"font_size", UiTheme.FONT_SIZE_SMALL)
	detail.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
	detail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	detail.offset_top = -22
	detail.offset_bottom = -4
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_button.add_child(detail)
	continue_button.pressed.connect(continue_game)
	quit_button = _button(box, "QuitButton", "Beenden")
	quit_button.pressed.connect(quit_game)
	var version := Label.new()
	version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "")
	version.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position += Vector2(-150, -40)
	root.add_child(version)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.name = "ConfirmNewGame"
	confirm_dialog.title = "Neues Spiel"
	confirm_dialog.dialog_text = "Ein neues Spiel überschreibt deinen Spielstand.\nTrotzdem beginnen?"
	confirm_dialog.ok_button_text = "Neu beginnen"
	confirm_dialog.cancel_button_text = "Zurück"
	confirm_dialog.confirmed.connect(func() -> void: start_new_game(true))
	root.add_child(confirm_dialog)


func _button(parent: Control, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override(&"font_size", 22)
	parent.add_child(button)
	return button
