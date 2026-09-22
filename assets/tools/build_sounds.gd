extends SceneTree
## Baut die Klang-Ressourcen (AudioStreamRandomizer) unter assets/audio/ (AP8).
##
## Aufruf (nach einem Import und nach assets/tools/synth_sounds.py):
##   godot --headless --path . -s res://assets/tools/build_sounds.gd
##
## Jede Ressource mischt mehrere Varianten und verstimmt leicht, damit sich Wiederholungen
## nicht gleich anhören. Nutzung im Spiel über die Klasse GameSounds (assets/audio/game_sounds.gd).

const AUDIO := "res://assets/audio/"
const SYNTH := AUDIO + "synth/"
const KENNEY := AUDIO + "kenney/"

## Name → [Dateien, Tonhöhen-Streuung, Lautstärke-Streuung in dB]
const SOUNDS := {
	"footstep":
	[
		[
			SYNTH + "footstep_1.wav",
			SYNTH + "footstep_2.wav",
			SYNTH + "footstep_3.wav",
			SYNTH + "footstep_4.wav",
			KENNEY + "land.ogg",
		],
		1.12,
		3.0,
	],
	"swing": [[SYNTH + "swing_1.wav", SYNTH + "swing_2.wav", SYNTH + "swing_3.wav"], 1.1, 2.0],
	"impact": [[SYNTH + "impact_1.wav", SYNTH + "impact_2.wav", SYNTH + "impact_3.wav"], 1.1, 2.0],
	"hurt": [[KENNEY + "enemy_hurt.ogg"], 1.15, 2.0],
	"death": [[KENNEY + "enemy_destroy.ogg"], 1.1, 1.0],
	"bone_break": [[KENNEY + "break.ogg"], 1.15, 1.0],
	"cast": [[KENNEY + "enemy_attack.ogg"], 1.1, 1.0],
	"loot_drop":
	[
		[
			KENNEY + "placement-a.ogg",
			KENNEY + "placement-b.ogg",
			KENNEY + "placement-c.ogg",
			KENNEY + "land.ogg",
		],
		1.1,
		2.0,
	],
	"loot_drop_rare": [[SYNTH + "loot_drop_rare.wav"], 1.03, 0.0],
	"loot_drop_legendary": [[SYNTH + "loot_drop_legendary.wav"], 1.0, 0.0],
	"loot_pickup":
	[
		[KENNEY + "placement-a.ogg", KENNEY + "placement-b.ogg", KENNEY + "placement-c.ogg"],
		1.2,
		1.0
	],
	"gold_pickup": [[KENNEY + "coin.ogg"], 1.1, 1.0],
}


func _init() -> void:
	var ok := true
	for sound_name: String in SOUNDS:
		var entry: Array = SOUNDS[sound_name]
		var randomizer := AudioStreamRandomizer.new()
		randomizer.random_pitch = entry[1]
		randomizer.random_volume_offset_db = entry[2]
		randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		for path: String in entry[0]:
			var stream := load(path) as AudioStream
			if stream == null:
				push_error("build_sounds: %s fehlt" % path)
				ok = false
				continue
			randomizer.add_stream(-1, stream)
		var target := AUDIO + sound_name + ".tres"
		if ResourceSaver.save(randomizer, target) != OK:
			push_error("build_sounds: %s nicht gespeichert" % target)
			ok = false
	print("build_sounds: ", "fertig (%d Klänge)" % SOUNDS.size() if ok else "mit Fehlern")
	quit(0 if ok else 1)
