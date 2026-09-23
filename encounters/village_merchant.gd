class_name VillageMerchant
extends Node3D
## Händlerin im Dorf am Marker merchant (AP6). Wer zu ihr läuft, sieht ihr Angebot und das Inventar
## (Fenster von AP7 über EventBus.merchant_opened); wer weggeht, schließt das Fenster.
## Das Angebot wird bei jedem Besuch im Dorf neu gewürfelt (Tabelle chest, Stufe des Spielers).

const MODEL_SCENE := "res://assets/characters/cultist_summoner.tscn"
const TABLE_PATH := "res://data/loot_tables/chest.tres"
const DISPLAY_NAME := "Händlerin Mira"
const TALK_RANGE := 3.2
const STOCK_SIZE := 10

## Fenster der Oberfläche (zum Schließen beim Weggehen). Darf leer sein.
var ui: GameUI
var stock: Array[ItemInstance] = []
var stock_level: int = 1

var _area: Area3D
var _is_talking: bool = false
var _restock_counter: int = 0


func _ready() -> void:
	_build_model()
	var label := Label3D.new()
	label.text = DISPLAY_NAME
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 10
	label.modulate = Color(1.0, 0.85, 0.5)
	label.position.y = 2.5
	add_child(label)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	lamp.position = Vector3(0.6, 2.2, 0.6)
	add_child(lamp)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = PhysicsLayers.PLAYER
	_area.monitorable = false
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TALK_RANGE
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position.y = 1.0
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


## Würfelt ein neues Angebot passend zur Stufe.
func restock(level: int) -> void:
	stock_level = maxi(level, 1)
	stock.clear()
	var table := load(TABLE_PATH) as LootTable
	while stock.size() < STOCK_SIZE:
		_restock_counter += 1
		var rng := Rng.stream(&"merchant", _restock_counter)
		var items := Loot.roll_drop(table, stock_level, rng)
		if items.is_empty():
			break
		for item in items:
			if stock.size() < STOCK_SIZE:
				stock.append(item)


func open_shop() -> void:
	if stock.is_empty():
		restock(stock_level)
	_is_talking = true
	EventBus.merchant_opened.emit(DISPLAY_NAME, stock)


func close_shop() -> void:
	_is_talking = false
	if ui != null and ui.merchant_window.is_open():
		ui.merchant_window.close_window()
		ui.inventory_window.close_window()


func is_talking() -> bool:
	return _is_talking


func _build_model() -> void:
	if not ResourceLoader.exists(MODEL_SCENE):
		return
	var model := (load(MODEL_SCENE) as PackedScene).instantiate() as Node3D
	# Eigene Farben statt des Kultisten-Karmesins, damit sie nicht wie ein Gegner aussieht.
	if &"albedo_override" in model:
		model.set(&"albedo_override", null)
	if &"tint" in model:
		model.set(&"tint", Color(0.95, 0.85, 0.7))
	add_child(model)


func _on_body_entered(body: Node3D) -> void:
	if ExitTrigger.is_player(body) and Components.is_alive(body):
		open_shop()


func _on_body_exited(body: Node3D) -> void:
	if ExitTrigger.is_player(body) and _is_talking:
		close_shop()
