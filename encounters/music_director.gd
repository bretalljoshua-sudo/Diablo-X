class_name MusicDirector
extends Node
## Spielt die Musik passend zur Lage: Dorf, Katakomben, Bosskampf, Titelbildschirm. Zwischen zwei
## Stücken wird überblendet. Läuft über den Bus „Music“ (Lautstärke in den Einstellungen, AP7).
## Die Stücke liegen unter assets/audio/music/ (erzeugt mit encounters/tools/compose_music.gd);
## fehlt eines, bleibt es still.

const TRACK_PATH := "res://assets/audio/music/%s.wav"
const MUSIC_BUS := &"Music"
const FADE_TIME := 2.0
const TRACK_VOLUME_DB := -6.0
const SILENT_DB := -60.0
const THEME_TRACKS: Dictionary[StringName, StringName] = {
	&"village": &"village",
	&"catacombs": &"catacombs",
	&"boss": &"catacombs",
}

## Hört selbst auf level_loaded und den Bosskampf. Aus = nur play() von außen.
@export var follow_game: bool = true

var current_track: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _level_track: StringName = &""
var _boss_active: bool = false
var _tweens: Array[Tween] = [null, null]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = MUSIC_BUS if AudioServer.get_bus_index(MUSIC_BUS) >= 0 else &"Master"
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	if follow_game:
		EventBus.level_loaded.connect(_on_level_loaded)
		EventBus.boss_encounter_started.connect(_on_boss_started)
		EventBus.boss_encounter_ended.connect(_on_boss_ended)


static func has_track(track: StringName) -> bool:
	return ResourceLoader.exists(TRACK_PATH % track)


## Blendet zu track über. Gleiches Stück läuft weiter.
func play(track: StringName) -> void:
	if track == current_track:
		return
	current_track = track
	_fade(_active, SILENT_DB, true)
	if track == &"" or not has_track(track):
		return
	_active = 1 - _active
	var player := _players[_active]
	player.stream = load(TRACK_PATH % track) as AudioStream
	player.volume_db = SILENT_DB
	player.play()
	_fade(_active, TRACK_VOLUME_DB, false)


func stop() -> void:
	play(&"")


func _fade(index: int, volume_db: float, stop_after: bool) -> void:
	if _tweens[index] != null and _tweens[index].is_valid():
		_tweens[index].kill()
	var player := _players[index]
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", volume_db, FADE_TIME)
	if stop_after:
		tween.tween_callback(player.stop)
	_tweens[index] = tween


func _on_level_loaded(layout: LevelLayout) -> void:
	_boss_active = false
	_level_track = THEME_TRACKS.get(layout.theme, &"catacombs")
	play(_level_track)


func _on_boss_started(_boss: Node3D, _display_name: String) -> void:
	_boss_active = true
	play(&"boss")


func _on_boss_ended(_boss: Node3D) -> void:
	if _boss_active:
		_boss_active = false
		play(_level_track)
