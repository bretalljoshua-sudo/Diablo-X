extends Node
## Reproduzierbarer Zufall. Jeder Dungeon und jeder Beutewurf bekommt einen eigenen
## Zufallsstrom aus einem Seed, damit sich Fehler mit demselben Seed nachstellen lassen.
##
## Start-Seed festlegen: Kommandozeile --seed=12345 (sonst zufällig, steht im Log).

var master_seed: int = 0

var _counter: int = 0


func _ready() -> void:
	var from_args := _seed_from_args(OS.get_cmdline_user_args() + OS.get_cmdline_args())
	set_master_seed(from_args if from_args != 0 else randi())
	print("Rng: master_seed=%d" % master_seed)


func set_master_seed(value: int) -> void:
	master_seed = value
	_counter = 0


## Neuer Zufallsstrom mit festem Seed.
func make(p_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	return rng


## Zufallsstrom für einen Zweck, abgeleitet vom master_seed.
## Gleicher master_seed, Zweck und Index ergeben immer denselben Strom.
func stream(purpose: StringName, index: int = 0) -> RandomNumberGenerator:
	return make(derive_seed(purpose, index))


func derive_seed(purpose: StringName, index: int = 0) -> int:
	return hash([master_seed, purpose, index])


## Liefert bei jedem Aufruf einen neuen, reproduzierbaren Seed (zum Beispiel pro Dungeon).
func next_seed(purpose: StringName) -> int:
	_counter += 1
	return derive_seed(purpose, _counter)


static func _seed_from_args(args: PackedStringArray) -> int:
	for arg in args:
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	return 0
