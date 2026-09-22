extends Node3D
## Leistungs-Testszene von AP1: Bossraum mit 50 animierten Gegnern (Modelle aus AP8), laufenden
## Treffern, Schadenszahlen, Blut, Auflösen und Beute-Lichtsäulen. Große FPS-Anzeige.
## Ziel laut Plan: 60 FPS in 1440p auf „Hoch“.
##
## Start: SpielJBR.exe --scene=graphics_perf [--enemies=50] [--benchmark] [--quality=2]
##   --benchmark misst jede Grafikstufe 12 Sekunden lang, schreibt das Ergebnis nach
##   user://benchmark.txt (Pfad steht im Log) und beendet das Spiel.
## Tasten: F5 bis F8 Grafikstufe (Niedrig bis Ultra) · B Messung dieser Stufe (12 s)
##         F11 Vollbild · P Effekte an/aus · Mausrad Zoom

const MODELS: PackedStringArray = ["skeleton_swarm", "ghoul", "skeleton_archer", "cultist_summoner"]
const DEFAULT_ENEMIES := 50
const MEASURE_SEC := 12.0
const WARMUP_SEC := 3.0
const HIT_INTERVAL := 0.12
const KILL_INTERVAL := 1.5

var enemy_count: int = DEFAULT_ENEMIES
var effects_enabled: bool = true
var actors: Array[GraphicsDemoActor] = []

var _rng := RandomNumberGenerator.new()
var _hit_timer: float = 0.0
var _kill_timer: float = 0.0
var _loot_timer: float = 0.0
var _frame_times: PackedFloat32Array = []
var _measuring: bool = false
var _measure_left: float = 0.0
var _warmup_left: float = 0.0
var _benchmark_queue: Array[int] = []
var _results: PackedStringArray = []

@onready var _level: Level = $Level
@onready var _fps: Label = $UI/Fps
@onready var _info: Label = $UI/Info


func _ready() -> void:
	_rng.seed = 11
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--enemies="):
			enemy_count = maxi(0, arg.trim_prefix("--enemies=").to_int())
		elif arg.begins_with("--quality="):
			Settings.quality = (
				clampi(arg.trim_prefix("--quality=").to_int(), 0, 3) as Settings.Quality
			)
			Settings.apply()
	EventBus.level_loaded.connect(_on_level_loaded)
	_level.load_depth(World.BOSS_DEPTH)
	if args.has("--benchmark"):
		_benchmark_queue.assign([0, 1, 2, 3])
		_start_next_benchmark()


func _process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_record(real_delta)
	if effects_enabled:
		_drive_effects(delta)
	_update_labels()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F5, KEY_F6, KEY_F7, KEY_F8:
			Settings.quality = (key.physical_keycode - KEY_F5) as Settings.Quality
			Settings.apply()
			_frame_times.clear()
		KEY_B:
			start_measure()
		KEY_F11:
			var fullscreen := (
				DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			)
			DisplayServer.window_set_mode(
				(
					DisplayServer.WINDOW_MODE_WINDOWED
					if fullscreen
					else DisplayServer.WINDOW_MODE_FULLSCREEN
				)
			)
		KEY_P:
			effects_enabled = not effects_enabled


## Startet eine Messung der aktuellen Stufe (erst Aufwärmen, dann MEASURE_SEC Sekunden).
func start_measure() -> void:
	_frame_times.clear()
	_warmup_left = WARMUP_SEC
	_measure_left = MEASURE_SEC
	_measuring = true


## Durchschnitt, 1-%-Tief und schlechtester Frame der letzten Messung in FPS bzw. ms.
static func summarize(frame_times: PackedFloat32Array) -> Dictionary:
	if frame_times.is_empty():
		return {"avg_fps": 0.0, "low_1_fps": 0.0, "worst_ms": 0.0, "frames": 0}
	var total := 0.0
	for t in frame_times:
		total += t
	var sorted := frame_times.duplicate()
	sorted.sort()
	var count := sorted.size()
	var worst_count := maxi(1, count / 100)
	var worst_total := 0.0
	for i in range(count - worst_count, count):
		worst_total += sorted[i]
	return {
		"avg_fps": count / total if total > 0.0 else 0.0,
		"low_1_fps": worst_count / worst_total if worst_total > 0.0 else 0.0,
		"worst_ms": sorted[count - 1] * 1000.0,
		"frames": count,
	}


func _on_level_loaded(layout: LevelLayout) -> void:
	for actor in actors:
		if is_instance_valid(actor):
			actor.queue_free()
	actors.clear()
	var center: Vector3 = layout.markers.get(&"boss_room_center", layout.player_start)
	var player := _level.player
	if player.has_method(&"teleport"):
		player.call(&"teleport", center)
	else:
		player.global_position = center
	_level.camera_rig.snap_to_target()
	_level.camera_rig.distance = 22.0
	# Gegner in Ringen um die Figur, alle im Bild.
	var ring := 0
	var placed := 0
	while placed < enemy_count:
		var in_ring := 8 + ring * 6
		var radius := 3.0 + ring * 1.7
		for i in in_ring:
			if placed >= enemy_count:
				break
			var angle := TAU * float(i) / in_ring + ring * 0.4
			var actor := GraphicsDemoActor.new()
			actor.model_name = MODELS[placed % MODELS.size()]
			actor.position = center + Vector3(cos(angle), 0, sin(angle)) * radius
			actor.wander_radius = 0.6 if placed % 3 == 0 else 0.0
			_level.actors.add_child(actor)
			actor.look_at(center, Vector3.UP, true)
			actors.append(actor)
			placed += 1
		ring += 1


func _drive_effects(delta: float) -> void:
	if actors.is_empty():
		return
	var player := _level.player
	_hit_timer -= delta
	while _hit_timer <= 0.0:
		_hit_timer += HIT_INTERVAL
		var target := actors[_rng.randi_range(0, actors.size() - 1)]
		var crit := _rng.randf() < 0.2
		target.take_hit(player, _rng.randf_range(10.0, 60.0), crit)
	_kill_timer -= delta
	if _kill_timer <= 0.0:
		_kill_timer = KILL_INTERVAL
		actors[_rng.randi_range(0, actors.size() - 1)].kill(player, 2.5)
	_loot_timer -= delta
	if _loot_timer <= 0.0 and Vfx.loot_beam_count() < 6:
		_loot_timer = 2.0
		var item := ItemInstance.new()
		item.rarity = [Enums.Rarity.RARE, Enums.Rarity.LEGENDARY, Enums.Rarity.UNIQUE].pick_random()
		var angle := _rng.randf() * TAU
		Vfx.add_loot_beam(
			item,
			player.global_position + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(2, 6)
		)


func _record(real_delta: float) -> void:
	if not _measuring:
		_frame_times.append(real_delta)
		if _frame_times.size() > 300:
			_frame_times.remove_at(0)
		return
	if _warmup_left > 0.0:
		_warmup_left -= real_delta
		return
	_frame_times.append(real_delta)
	_measure_left -= real_delta
	if _measure_left <= 0.0:
		_measuring = false
		_finish_measure()


func _finish_measure() -> void:
	var stats := summarize(_frame_times)
	var line := (
		(
			"%s: %.1f FPS im Schnitt, 1 %% Tiefs %.1f FPS, schlechtester Frame %.1f ms,"
			+ " %d Frames, %s, %d Gegner"
		)
		% [
			Graphics.get_preset().display_name,
			stats["avg_fps"],
			stats["low_1_fps"],
			stats["worst_ms"],
			stats["frames"],
			_resolution_text(),
			actors.size(),
		]
	)
	print("Leistung: " + line)
	_results.append(line)
	if not _benchmark_queue.is_empty():
		_start_next_benchmark()
	elif OS.get_cmdline_user_args().has("--benchmark") or OS.get_cmdline_args().has("--benchmark"):
		_write_results()
		get_tree().quit()


func _start_next_benchmark() -> void:
	var level: int = _benchmark_queue.pop_front()
	Settings.quality = level as Settings.Quality
	Settings.apply()
	start_measure()


func _write_results() -> void:
	var path := "user://benchmark.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(
		"Spiel JBR Leistungstest %s\n%s\n" % [Time.get_datetime_string_from_system(), _gpu_text()]
	)
	for line in _results:
		file.store_line(line)
	print("Leistung: Ergebnis in %s" % ProjectSettings.globalize_path(path))


func _update_labels() -> void:
	if Engine.get_process_frames() % 10 != 0:
		return
	var stats := summarize(_frame_times)
	var fps := Engine.get_frames_per_second()
	_fps.text = "%d FPS" % fps
	_fps.modulate = (
		Color(0.5, 1, 0.5)
		if fps >= 60
		else (Color(1, 0.85, 0.3) if fps >= 45 else Color(1, 0.4, 0.3))
	)
	var status := ""
	if _measuring:
		status = (
			"Aufwärmen …"
			if _warmup_left > 0.0
			else "Messung läuft: noch %d s" % ceili(_measure_left)
		)
	elif not _results.is_empty():
		status = "Letzte Messung: " + _results[_results.size() - 1]
	_info.text = (
		(
			"Grafikstufe %s  ·  %s  ·  %d Gegner  ·  Schnitt %.0f FPS, 1 %% Tiefs %.0f FPS  ·  %.1f ms"
			+ "  ·  Draw Calls %d\n%s\n%s\n"
			+ "F5–F8 Grafikstufe · B Messung (12 s) · F11 Vollbild · P Effekte an/aus · Mausrad Zoom"
		)
		% [
			Graphics.get_preset().display_name,
			_resolution_text(),
			actors.size(),
			stats["avg_fps"],
			stats["low_1_fps"],
			1000.0 / maxf(fps, 1.0),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			_gpu_text(),
			status,
		]
	)


func _resolution_text() -> String:
	var size := get_viewport().get_visible_rect().size
	var window := (
		DisplayServer.window_get_size()
		if DisplayServer.get_name() != "headless"
		else Vector2i(size)
	)
	return "%d × %d" % [window.x, window.y]


static func _gpu_text() -> String:
	return (
		"%s · %s"
		% [
			RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_api_version()
		]
	)
