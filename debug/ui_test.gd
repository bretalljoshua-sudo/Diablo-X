extends Node3D
## Testszene für AP7 „UI und Inventar“. Start: --scene=ui_test
##
## Echte Gegenstände aus AP4, Beispieldaten für alles, was noch fehlt (Skills, Gegner, Boss,
## Händler, Karte). Tasten siehe HINT.
##
## Für Screenshots: --ui-open=inventory,skills,merchant,map,pause,settings,labels,boss,tooltip
## öffnet Fenster gleich beim Start, zum Beispiel
##   SpielJBR.exe --scene=ui_test --ui-open=inventory,merchant --screenshot=ui.png

const HINT := (
	"I Inventar · K Skillbaum · M Karte · Esc Menü · Alt Beute beschriften · Q Heiltrank · WASD laufen"
	+ "\n1–4 Skills einsetzen · 5 Schaden nehmen · 6 Erfahrung · 7 Beute fallen lassen · 8 Bosskampf"
	+ " · 9 Händler · 0 Stufenaufstieg"
)
const SKILLS_SCRIPT := preload("res://debug/ui_test_skills.gd")
const DUMMY_SCRIPT := preload("res://debug/ui_test_dummy.gd")
const PLAYER_SCRIPT := preload("res://debug/ui_test_player.gd")
const ENEMY_NAMES: Array[String] = ["Skelettkrieger", "Ghul", "Skelettbogenschütze", "Kultist"]

var player: Node3D
var inventory: Inventory
var equipment: Equipment
var skills: Node
var ui: GameUI
var dummies: Array[StaticBody3D] = []
var boss: StaticBody3D
var layout: LevelLayout

var _drops: Node3D
var _drop_counter: int = 0
var _damage_timer: float = 0.0
var _hovered: Node3D


func _ready() -> void:
	_build_world()
	# Die UI zuerst, damit sie die Startwerte von Spieler und Skills mitbekommt.
	ui = (load("res://ui/game_ui.tscn") as PackedScene).instantiate() as GameUI
	add_child(ui)
	player = _build_player()
	Game.player = player
	inventory = Inventory.find_on(player)
	equipment = Equipment.find_on(player)
	skills = SKILLS_SCRIPT.new()
	skills.name = "SampleSkills"
	add_child(skills)
	_fill_inventory()
	_build_dummies()
	layout = make_sample_layout()
	EventBus.level_loaded.emit(layout)
	for spot: Vector3 in [Vector3(-2, 0, 3), Vector3(2.5, 0, 2.5), Vector3(0, 0, 4.5)]:
		drop_loot(spot)
	var hint := Label.new()
	hint.text = HINT
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = 96
	hint.add_theme_font_size_override(&"font_size", 14)
	hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	hint.add_theme_constant_override(&"outline_size", 4)
	var hint_layer := CanvasLayer.new()
	hint_layer.add_child(hint)
	add_child(hint_layer)
	_open_from_args.call_deferred()


## Öffnet Fenster laut --ui-open=… (für Screenshots).
func _open_from_args() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if not arg.begins_with("--ui-open="):
			continue
		for part in arg.trim_prefix("--ui-open=").split(",", false):
			match part.strip_edges():
				"inventory", "skills", "map", "pause":
					ui.toggle_window(StringName(part.strip_edges()))
				"merchant":
					open_merchant()
				"labels":
					ui.ground_labels.force_visible = true
				"boss":
					toggle_boss()
				"tooltip":
					_show_first_tooltip.call_deferred()
				"settings":
					ui.toggle_window(&"pause")
					ui.pause_menu.show_settings()


func _show_first_tooltip() -> void:
	await get_tree().process_frame
	var items := inventory.get_items()
	if items.is_empty():
		return
	var item := items[0]
	var grid := ui.inventory_window.grid
	grid.item_hovered.emit(item, grid.item_global_rect(item))


func _exit_tree() -> void:
	if Game.player == player:
		Game.player = null


func _process(delta: float) -> void:
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = 1.2
		_hit_random_dummy()
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	for i in 4:
		if event.is_action_pressed(StringName("skill_%d" % (i + 1))):
			skills.cast(SkillBar.FIRST_KEY_SLOT + i, player)
			get_viewport().set_input_as_handled()
			return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_5:
			player.take_damage(35.0)
		KEY_6:
			skills.gain_experience(60)
		KEY_7:
			drop_loot(player.global_position + Vector3(randf_range(-3, 3), 0, randf_range(2, 4)))
		KEY_8:
			toggle_boss()
		KEY_9:
			open_merchant()
		KEY_0:
			skills.gain_experience(skills.required_experience() - skills.experience)
		_:
			return
	get_viewport().set_input_as_handled()


## Lässt einen Boss-Drop an position fallen.
func drop_loot(position: Vector3) -> void:
	_drop_counter += 1
	Loot.drop_at(
		Loot.get_table(&"elite"), 5, Rng.stream(&"ui_test", _drop_counter), position, _drops
	)


func open_merchant() -> void:
	var stock: Array[ItemInstance] = []
	var rng := Rng.stream(&"ui_test_merchant", _drop_counter)
	while stock.size() < 10:
		stock.append_array(Loot.roll_drop(Loot.get_table(&"chest"), 5, rng))
	EventBus.merchant_opened.emit("Händlerin Mira", stock)


func toggle_boss() -> void:
	if boss.visible:
		EventBus.boss_encounter_ended.emit(boss)
		boss.visible = false
		return
	boss.revive()
	EventBus.boss_encounter_started.emit(boss, "Der Gruftwächter")
	EventBus.entity_health_changed.emit(boss, boss.health, boss.max_health)


## Beispiel-Layout für die Minikarte: Räume auf einem 4-m-Raster, verbunden durch Gänge.
static func make_sample_layout() -> LevelLayout:
	var result := LevelLayout.new()
	result.depth = 1
	result.theme = &"catacombs"
	result.cell_size = Vector3(4, 4, 4)
	result.rooms = [
		Rect2i(-3, -3, 6, 6), Rect2i(6, -2, 5, 4), Rect2i(-2, 7, 4, 5), Rect2i(-12, -1, 5, 5)
	]
	result.room_links = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
	for room in result.rooms:
		_carve(result, room)
	_carve(result, Rect2i(3, -1, 3, 1))
	_carve(result, Rect2i(0, 3, 1, 4))
	_carve(result, Rect2i(-7, 0, 4, 1))
	# Wände um alle begehbaren Zellen.
	var walls: Array[Vector3i] = []
	for cell: Vector3i in result.cells:
		for dir: Vector3i in [
			Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)
		]:
			if not result.cells.has(cell + dir):
				walls.append(cell + dir)
	for wall in walls:
		result.cells[wall] = 3
	result.exits = [Vector3(38, 0, 0)]
	result.entrance = Vector3(-38, 0, 6)
	result.markers = {&"portal": Vector3(2, 0, 38), &"merchant": Vector3(-6, 0, -6)}
	return result


static func _carve(target: LevelLayout, rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			target.cells[Vector3i(x, 0, z)] = 0


func _fill_inventory() -> void:
	var rng := Rng.stream(&"ui_test_inventory", 1)
	var tables: Array[StringName] = [&"boss", &"elite", &"chest"]
	var tries := 0
	while inventory.get_item_count() < 14 and tries < 30:
		for item in Loot.roll_drop(Loot.get_table(tables[tries % tables.size()]), 6, rng):
			inventory.add_item(item)
		tries += 1
	# Ein paar schwache Stücke angelegt, damit der Vergleich etwas zu zeigen hat.
	var normal := Loot.get_table(&"normal")
	for i in 12:
		for item in Loot.roll_drop(normal, 1, rng):
			if equipment.get_item(maxi(equipment.choose_slot(item), 0)) == null:
				equipment.equip(item)
	inventory.add_gold(1500)


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.42, 0.5)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_color = Color(0.75, 0.78, 0.95)
	light.shadow_enabled = true
	add_child(light)
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.1
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(40, 0.2, 40)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.19, 0.18)
	box.material = material
	floor_mesh.mesh = box
	floor_body.add_child(floor_mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	floor_body.add_child(shape)
	add_child(floor_body)
	_drops = Node3D.new()
	_drops.name = "Drops"
	add_child(_drops)


func _build_player() -> Node3D:
	var node := Node3D.new()
	node.name = "Player"
	var inv := Inventory.new()
	inv.name = "Inventory"
	node.add_child(inv)
	var equip := Equipment.new()
	equip.name = "Equipment"
	node.add_child(equip)
	node.set_script(PLAYER_SCRIPT)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.12, 0.08)
	capsule.material = material
	mesh.mesh = capsule
	mesh.position.y = 0.9
	node.add_child(mesh)
	add_child(node)
	var rig := CameraRig.new()
	rig.name = "CameraRig"
	rig.target = node
	rig.distance = 20.0
	add_child(rig)
	return node


func _build_dummies() -> void:
	for i in ENEMY_NAMES.size():
		var angle := TAU * i / ENEMY_NAMES.size() + 0.4
		var dummy := _make_dummy(ENEMY_NAMES[i], i == 1, 120.0, 0.45, Color(0.35, 0.4, 0.3))
		dummy.position = Vector3(cos(angle), 0, sin(angle)) * 6.0
		dummies.append(dummy)
	boss = _make_dummy("Der Gruftwächter", false, 2000.0, 1.0, Color(0.3, 0.1, 0.35))
	boss.position = Vector3(0, 0, -9)
	boss.visible = false


func _make_dummy(
	display_name: String, elite: bool, health: float, radius: float, color: Color
) -> StaticBody3D:
	var dummy := StaticBody3D.new()
	dummy.set_script(DUMMY_SCRIPT)
	dummy.set(&"display_name", display_name)
	dummy.set(&"is_elite", elite)
	dummy.set(&"max_health", health)
	dummy.collision_layer = PhysicsLayers.ENEMY
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = radius * 4.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	capsule.material = material
	mesh.mesh = capsule
	mesh.position.y = radius * 2.0
	dummy.add_child(mesh)
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = radius
	capsule_shape.height = radius * 4.0
	shape.shape = capsule_shape
	shape.position.y = radius * 2.0
	dummy.add_child(shape)
	add_child(dummy)
	return dummy


func _hit_random_dummy() -> void:
	if boss.visible:
		var before: float = boss.health
		boss.take_damage(90.0)
		if before > boss.max_health * 0.5 and boss.health <= boss.max_health * 0.5:
			EventBus.boss_phase_changed.emit(boss, 2)
		if boss.health <= 0.0:
			EventBus.boss_encounter_ended.emit(boss)
		return
	var dummy := dummies[randi() % dummies.size()]
	if not dummy.visible:
		dummy.revive()
		return
	dummy.take_damage(randf_range(15.0, 40.0))


func _update_hover() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		from, from + camera.project_ray_normal(mouse) * 200.0, PhysicsLayers.ENEMY
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target := hit.get("collider") as Node3D
	if target != null and not target.visible:
		target = null
	if target != _hovered:
		_hovered = target
		EventBus.hovered_target_changed.emit(target)
