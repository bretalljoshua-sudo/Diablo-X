class_name ItemDatabase
extends RefCounted
## Alle Beute-Inhalte aus data/: Grundformen, Affixe, Aspekte, einzigartige Gegenstände,
## Namensbausteine, Seltenheitsverteilung und Skill-Tags.
##
## Neue Inhalte sind neue .tres-Dateien in den Ordnern unten, kein neuer Code.
## ItemDatabase.get_default() lädt einmal und merkt sich das Ergebnis.

const ITEMS_DIR := "res://data/items"
const AFFIXES_DIR := "res://data/affixes"
const ASPECTS_DIR := "res://data/aspects"
const RARITY_PATH := "res://data/loot_tables/rarity.tres"
const NAME_PARTS_PATH := "res://data/items/name_parts.tres"
const SKILL_TAGS_PATH := "res://data/aspects/skill_tags.tres"
const RING_SLOTS: Array[Enums.Slot] = [Enums.Slot.RING_1, Enums.Slot.RING_2]

static var _default: ItemDatabase

var bases: Array[ItemBase] = []
var affixes: Array[AffixDef] = []
var aspects: Array[AspectDef] = []
var uniques: Array[UniqueDef] = []
var rarity: RaritySettings
var name_parts: NameParts
var skill_tags: SkillTagCatalog


static func get_default() -> ItemDatabase:
	if _default == null:
		_default = load_from_data()
	return _default


static func load_from_data() -> ItemDatabase:
	var db := ItemDatabase.new()
	for res: Resource in _load_all(ITEMS_DIR):
		if res is ItemBase:
			db.bases.append(res)
		elif res is UniqueDef:
			db.uniques.append(res)
	for res: Resource in _load_all(AFFIXES_DIR):
		if res is AffixDef:
			db.affixes.append(res)
	for res: Resource in _load_all(ASPECTS_DIR):
		if res is AspectDef:
			db.aspects.append(res)
	db.rarity = load(RARITY_PATH) as RaritySettings
	db.name_parts = load(NAME_PARTS_PATH) as NameParts
	db.skill_tags = load(SKILL_TAGS_PATH) as SkillTagCatalog
	return db


## true, wenn ein Gegenstand mit Grundplatz base_slot in den Platz slot passt.
## Ringe haben den Grundplatz RING_1 und passen in beide Ringplätze.
static func slot_matches(base_slot: Enums.Slot, slot: Enums.Slot) -> bool:
	if base_slot == slot:
		return true
	return base_slot in RING_SLOTS and slot in RING_SLOTS


func get_base(id: StringName) -> ItemBase:
	for base in bases:
		if base.id == id:
			return base
	return null


func get_affix(id: StringName) -> AffixDef:
	for affix in affixes:
		if affix.id == id:
			return affix
	return null


func get_aspect(id: StringName) -> AspectDef:
	for aspect in aspects:
		if aspect.id == id:
			return aspect
	return null


func get_unique(id: StringName) -> UniqueDef:
	for def in uniques:
		if def.id == id:
			return def
	return null


## Der einzigartige Gegenstand, zu dem eine Kraft gehört (zum Laden von Spielständen).
func get_unique_by_power(power_id: StringName) -> UniqueDef:
	for def in uniques:
		if def.power != null and def.power.id == power_id:
			return def
	return null


## Affixe, die auf einer Grundform erscheinen dürfen.
func affixes_for(base: ItemBase) -> Array[AffixDef]:
	var result: Array[AffixDef] = []
	for affix in affixes:
		if affix.allowed_slots.is_empty():
			result.append(affix)
			continue
		for slot: Enums.Slot in affix.allowed_slots:
			if slot_matches(base.slot, slot):
				result.append(affix)
				break
	return result


## Lädt alle Ressourcen eines Ordners samt Unterordnern, sortiert nach Pfad.
static func _load_all(dir: String) -> Array[Resource]:
	var result: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(dir):
		return result
	var names := Array(ResourceLoader.list_directory(dir))
	names.sort()
	for file_name: String in names:
		var path := dir.path_join(file_name)
		if file_name.ends_with("/"):
			result.append_array(_load_all(path.trim_suffix("/")))
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var res := load(path)
			if res != null:
				result.append(res)
	return result
