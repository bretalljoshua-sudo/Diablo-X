extends Node
## Autoload „Loot“: würfelt Beute aus Beutetabellen und legt sie in die Welt.
##
## Vertrag: roll_drop(table: LootTable, level: int, rng: RandomNumberGenerator)
##          -> Array[ItemInstance]
## Den Zufallsstrom liefert Rng.stream(&"loot", …), damit Drops reproduzierbar sind.
## Gold würfelt roll_gold() getrennt, weil es kein Gegenstand ist.
##
## Beutetabellen: data/loot_tables/normal.tres, elite.tres, boss.tres, chest.tres.

const TABLES_DIR := "res://data/loot_tables"
## Zuwachs der Goldmenge je Stufe über 1 (0.25 = +25 % pro Stufe).
const GOLD_PER_LEVEL := 0.25
## Abstand der Gegenstände am Boden vom Mittelpunkt des Drops.
const DROP_RADIUS := 1.2

var generator: ItemGenerator:
	get:
		if generator == null:
			generator = ItemGenerator.new()
		return generator


## Würfelt die Gegenstände eines Drops. Eine Tabelle ohne Einträge (oder null) liefert
## genau einen Gegenstand aus allen Grundformen.
func roll_drop(table: LootTable, level: int, rng: RandomNumberGenerator) -> Array[ItemInstance]:
	if rng == null:
		rng = Rng.stream(&"loot", Time.get_ticks_usec())
	return generator.roll_items(table, maxi(level, 1), rng)


## Goldmenge eines Drops, wächst mit der Stufe. 0, wenn die Tabelle kein Gold hat.
func roll_gold(table: LootTable, level: int, rng: RandomNumberGenerator) -> int:
	if table == null or table.gold.y <= 0:
		return 0
	var amount := rng.randi_range(maxi(table.gold.x, 0), maxi(table.gold.x, table.gold.y))
	return int(roundf(amount * (1.0 + GOLD_PER_LEVEL * (maxi(level, 1) - 1))))


## Beutetabelle aus data/loot_tables, zum Beispiel get_table(&"elite"), sonst null.
func get_table(table_name: StringName) -> LootTable:
	var path := "%s/%s.tres" % [TABLES_DIR, table_name]
	if not ResourceLoader.exists(path):
		push_warning("Loot: Beutetabelle '%s' gibt es nicht." % table_name)
		return null
	return load(path) as LootTable


## Würfelt einen Drop und legt Gegenstände und Gold als GroundItem um position herum ab.
## Sendet EventBus.loot_dropped für jeden Gegenstand. Für Gegner (AP3) und Truhen (AP9).
func drop_at(
	table: LootTable, level: int, rng: RandomNumberGenerator, position: Vector3, parent: Node
) -> Array[GroundItem]:
	var spawned: Array[GroundItem] = []
	if parent == null:
		return spawned
	var items := roll_drop(table, level, rng)
	var gold := roll_gold(table, level, rng)
	var count := items.size() + (1 if gold > 0 else 0)
	var angle := rng.randf() * TAU
	for item in items:
		var spot := position + _offset(angle, count)
		angle += TAU / maxf(count, 1)
		spawned.append(GroundItem.spawn_item(parent, item, spot))
		EventBus.loot_dropped.emit(item, spot)
	if gold > 0:
		spawned.append(GroundItem.spawn_gold(parent, gold, position + _offset(angle, count)))
	return spawned


static func _offset(angle: float, count: int) -> Vector3:
	if count <= 1:
		return Vector3.ZERO
	return Vector3(cos(angle), 0.0, sin(angle)) * DROP_RADIUS
