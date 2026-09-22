class_name DamageNumber
extends Label3D
## Schwebende Schadenszahl über einer Figur: springt kurz auf, steigt, driftet zur Seite und
## verblasst. Kommt aus dem Pool der Autoload Vfx.

signal finished(number: DamageNumber)

const LIFETIME := 0.9
const LIFETIME_CRIT := 1.2
const RISE := 1.4
const POP_TIME := 0.12

## Farben je Art: normal, kritisch, Schaden am Spieler, Feuer, Kälte, Gift.
const COLOR_NORMAL := Color(1.0, 0.96, 0.9)
const COLOR_CRIT := Color(1.0, 0.78, 0.2)
const COLOR_PLAYER := Color(1.0, 0.25, 0.2)
const TYPE_COLORS: Dictionary[Enums.DamageType, Color] = {
	Enums.DamageType.FIRE: Color(1.0, 0.55, 0.2),
	Enums.DamageType.COLD: Color(0.55, 0.8, 1.0),
	Enums.DamageType.POISON: Color(0.55, 0.95, 0.35),
}

var _age: float = 0.0
var _lifetime: float = LIFETIME
var _start: Vector3
var _drift: Vector3
var _base_scale: float = 1.0
var _active: bool = false


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	pixel_size = 0.0045
	font_size = 72
	outline_size = 18
	outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
	render_priority = 10
	outline_render_priority = 9
	double_sided = true
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	set_process(false)


## Zeigt amount an at. crit vergrößert die Zahl, to_player färbt sie rot.
func show_damage(
	at: Vector3,
	amount: float,
	crit: bool,
	to_player: bool,
	type: Enums.DamageType = Enums.DamageType.PHYSICAL
) -> void:
	text = str(maxi(1, roundi(amount)))
	if crit:
		text += "!"
	modulate = color_for(crit, to_player, type)
	_base_scale = 1.45 if crit else 1.0
	_lifetime = LIFETIME_CRIT if crit else LIFETIME
	_start = at
	_drift = Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	_age = 0.0
	_active = true
	global_position = at
	scale = Vector3.ONE * _base_scale * 1.6
	visible = true
	set_process(true)


static func color_for(crit: bool, to_player: bool, type: Enums.DamageType) -> Color:
	if to_player:
		return COLOR_PLAYER
	if crit:
		return COLOR_CRIT
	return TYPE_COLORS.get(type, COLOR_NORMAL)


func is_active() -> bool:
	return _active


func stop() -> void:
	if not _active:
		return
	_active = false
	visible = false
	set_process(false)
	finished.emit(self)


func _process(delta: float) -> void:
	# In Echtzeit, damit der Trefferstopp (Engine.time_scale) die Zahl nicht einfriert.
	_age += delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	var t := clampf(_age / _lifetime, 0.0, 1.0)
	var rise := 1.0 - pow(1.0 - t, 2.5)
	global_position = _start + Vector3(0, rise * RISE, 0) + _drift * t
	var pop := clampf(_age / POP_TIME, 0.0, 1.0)
	scale = Vector3.ONE * _base_scale * lerpf(1.6, 1.0, pop)
	var alpha := 1.0 - smoothstep(0.65, 1.0, t)
	modulate.a = alpha
	outline_modulate.a = alpha * 0.9
	if t >= 1.0:
		stop()
