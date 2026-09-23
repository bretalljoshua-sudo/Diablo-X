class_name SaveGame
extends RefCounted
## Inhalt des Spielstands (AP9). Geschrieben wird über SaveService (AP0) nach user://savegame.json,
## zusammen mit dessen Versionsnummer. Dieser Aufbau hat eine eigene Formatnummer (FORMAT), damit
## spätere Versionen alte Stände umbauen können (migrate).
##
## {
##   "format": 1, "game_version": "0.1.0", "saved_at": 1790000000,
##   "character": {"class": "warrior"},
##   "skills": SkillUser.to_dict()        Stufe, Erfahrung, Punkte, Ränge, Skillleiste
##   "inventory": {"gold": …, "items": […]}, "equipment": {…}   ItemSerializer (AP4)
##   "potions": 4,
##   "progress": {"runs_completed", "best_run_sec", "boss_kills", "deaths", "play_time_sec"}
## }
##
## Einstellungen (Grafik, Ton, Tasten) liegen getrennt in user://settings.cfg (Settings, AP0/AP7)
## und werden bei jedem Speichern mitgeschrieben.

const FORMAT := 1
const CHARACTER_CLASS := "warrior"
const PROGRESS_KEYS: Array[String] = [
	"runs_completed", "best_run_sec", "boss_kills", "deaths", "play_time_sec"
]


## Leerer Fortschritt für ein neues Spiel.
static func new_progress() -> Dictionary:
	return {
		"runs_completed": 0,
		"best_run_sec": 0.0,
		"boss_kills": 0,
		"deaths": 0,
		"play_time_sec": 0.0,
	}


static func collect(player: Node, progress: Dictionary) -> Dictionary:
	var data := {
		"format": FORMAT,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": int(Time.get_unix_time_from_system()),
		"character": {"class": CHARACTER_CLASS},
		"progress": progress.duplicate(),
	}
	var skills := SkillUser.find_on(player)
	if skills != null:
		data["skills"] = skills.to_dict()
	var inventory := Inventory.find_on(player)
	if inventory != null:
		data["inventory"] = ItemSerializer.inventory_to_dict(inventory)
	var equipment := Equipment.find_on(player)
	if equipment != null:
		data["equipment"] = ItemSerializer.equipment_to_dict(equipment)
	if player is Player:
		data["potions"] = (player as Player).potions.charges
	return data


## Überträgt einen Spielstand auf die Spielerfigur. Leben und Tränke sind danach voll.
static func apply(player: Node, raw: Dictionary) -> void:
	var data := migrate(raw)
	var equipment := Equipment.find_on(player)
	if equipment != null and data.get("equipment") is Dictionary:
		ItemSerializer.equipment_from_dict(equipment, data["equipment"])
	var inventory := Inventory.find_on(player)
	if inventory != null and data.get("inventory") is Dictionary:
		ItemSerializer.inventory_from_dict(inventory, data["inventory"])
		EventBus.gold_changed.emit(inventory.gold, 0)
	var skills := SkillUser.find_on(player)
	if skills != null and data.get("skills") is Dictionary:
		skills.from_dict(data["skills"])
	if player is Player:
		var body := player as Player
		body.health.reset_to_full()
		body.potions.refill()


## Fortschritt aus einem Spielstand, fehlende Einträge mit Startwerten.
static func progress_of(raw: Dictionary) -> Dictionary:
	var progress := new_progress()
	var saved: Variant = migrate(raw).get("progress", {})
	if saved is Dictionary:
		for key in PROGRESS_KEYS:
			if (saved as Dictionary).has(key):
				progress[key] = saved[key]
	return progress


## Baut ältere Formate auf FORMAT um. Format 1 ist das erste, hier gibt es noch nichts zu tun.
static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var format := int(data.get("format", 1))
	if format > FORMAT:
		push_warning(
			"SaveGame: Spielstand hat Format %d, dieses Spiel kennt %d." % [format, FORMAT]
		)
	data["format"] = FORMAT
	return data


## Speichert die Figur und den Fortschritt (und die Einstellungen).
static func write(player: Node, progress: Dictionary) -> Error:
	if player == null or not is_instance_valid(player):
		return ERR_INVALID_PARAMETER
	var err := SaveService.save_game(collect(player, progress))
	Settings.save_settings()
	return err


static func read() -> Dictionary:
	return migrate(SaveService.load_game()) if SaveService.has_save() else {}


## Kurzbeschreibung für den Titelbildschirm, zum Beispiel „Krieger · Stufe 5 · 2 Durchläufe“.
static func summary(raw: Dictionary) -> String:
	if raw.is_empty():
		return ""
	var skills: Dictionary = raw.get("skills", {})
	var progress := progress_of(raw)
	var runs := int(progress["runs_completed"])
	var text := "Krieger · Stufe %d" % int(skills.get("level", 1))
	if runs > 0:
		text += " · %d %s" % [runs, "Durchlauf" if runs == 1 else "Durchläufe"]
	var gold := int((raw.get("inventory", {}) as Dictionary).get("gold", 0))
	text += " · %d Gold" % gold
	return text


## Ordner des Spielstands als Pfad des Betriebssystems (für README und Titelbildschirm).
static func save_location() -> String:
	return ProjectSettings.globalize_path(SaveService.save_path)
