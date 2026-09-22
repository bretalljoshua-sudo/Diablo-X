class_name SkillBar
extends HBoxContainer
## Skillleiste mit sechs Plätzen: linke und rechte Maustaste, Tasten 1 bis 4.
## Hört auf skill_slot_changed, skill_cooldown_started, skill_cast, skill_cast_failed und
## resource_changed.

signal slot_clicked(slot: int)

const SLOT_COUNT := 6
## Index des ersten Tasten-Platzes (Taste 1).
const FIRST_KEY_SLOT := 2
const SLOT_LABELS: Array[String] = ["LM", "RM", "1", "2", "3", "4"]
const SLOT_NAMES: Array[String] = [
	"Linke Maustaste", "Rechte Maustaste", "Taste 1", "Taste 2", "Taste 3", "Taste 4"
]
const SLOT_ACTIONS: Array[StringName] = [
	&"primary_action", &"secondary_action", &"skill_1", &"skill_2", &"skill_3", &"skill_4"
]
const CATEGORY_COLORS: Dictionary[Enums.SkillCategory, Color] = {
	Enums.SkillCategory.BASIC: Color(0.75, 0.55, 0.35),
	Enums.SkillCategory.CORE: Color(0.85, 0.25, 0.15),
	Enums.SkillCategory.DEFENSIVE: Color(0.35, 0.55, 0.85),
	Enums.SkillCategory.MOBILITY: Color(0.35, 0.75, 0.45),
	Enums.SkillCategory.ULTIMATE: Color(0.9, 0.7, 0.2),
}

var slots: Array[SkillSlot] = []
var resource_current: float = 0.0


func _init() -> void:
	name = "SkillBar"
	add_theme_constant_override(&"separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in SLOT_COUNT:
		var slot := SkillSlot.new(i)
		slot.clicked.connect(func() -> void: slot_clicked.emit(i))
		add_child(slot)
		slots.append(slot)
	EventBus.skill_slot_changed.connect(set_slot)
	EventBus.skill_cooldown_started.connect(start_cooldown)
	EventBus.skill_cast.connect(_on_skill_cast)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.skill_cast_failed.connect(_on_skill_cast_failed)


func set_slot(slot: int, skill: SkillDef) -> void:
	if slot < 0 or slot >= slots.size():
		return
	slots[slot].set_skill(skill)
	slots[slot].affordable = skill == null or skill.cost <= resource_current + 0.001


## Startet die Abklingzeit auf allen Plätzen mit diesem Skill.
func start_cooldown(skill: SkillDef, duration: float) -> void:
	for slot in slots:
		if slot.skill != null and skill != null and slot.skill.id == skill.id:
			slot.start_cooldown(duration)


func get_slot_for(skill: SkillDef) -> SkillSlot:
	for slot in slots:
		if slot.skill != null and skill != null and slot.skill.id == skill.id:
			return slot
	return null


## Farbe je Kategorie für Platzhalter-Symbole.
static func category_color(skill: SkillDef) -> Color:
	if skill == null:
		return UiTheme.BORDER
	return CATEGORY_COLORS.get(skill.category, UiTheme.BORDER)


## „Wirbelsturm“ → „Wi“, „Zorn der Ahnen“ → „ZA“: Platzhalter, bis AP8 Symbole liefert.
static func initials(skill: SkillDef) -> String:
	if skill == null or skill.display_name.is_empty():
		return "?"
	var words := skill.display_name.split(" ", false)
	var capitals := PackedStringArray()
	for word in words:
		if word.substr(0, 1) == word.substr(0, 1).to_upper():
			capitals.append(word.substr(0, 1))
	if capitals.size() >= 2:
		return "".join(capitals.slice(0, 2))
	return skill.display_name.substr(0, 2)


## Beschriftung der Taste eines Platzes, folgt der eigenen Tastenbelegung.
static func key_label(slot: int) -> String:
	if slot < FIRST_KEY_SLOT:
		return SLOT_LABELS[slot]
	var key := Settings.get_key_binding(SLOT_ACTIONS[slot])
	return OS.get_keycode_string(key) if key != KEY_NONE else SLOT_LABELS[slot]


func _on_skill_cast(_caster: Node3D, skill: SkillDef, _target: Vector3) -> void:
	var slot := get_slot_for(skill)
	if slot != null:
		slot.flash()


## Fehlschlag (Abklingzeit, zu wenig Wut, …): der Platz blinkt rot.
func _on_skill_cast_failed(skill: SkillDef, _reason: StringName) -> void:
	var slot := get_slot_for(skill)
	if slot != null:
		slot.flash(UiTheme.WORSE)


func _on_resource_changed(current: float, _maximum: float) -> void:
	resource_current = current
	for slot in slots:
		slot.affordable = slot.skill == null or slot.skill.cost <= current + 0.001
