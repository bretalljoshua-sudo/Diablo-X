extends Node
## Autoload „Vfx“ (AP1): Effekte aus Pools, Schadenszahlen, Treffer-Aufblitzen, Blut am Boden,
## Auflösen beim Tod und Beute-Lichtsäulen.
##
## Andere Pakete müssen nichts aufrufen. Vfx hört auf:
##   damage_dealt   → Schadenszahl, Treffer-Effekt je Schadensart, Aufblitzen, Blut am Boden
##   entity_died    → Auflösen des Modells, Staub und Glut, Blutlache
##   entity_spawned → setzt Auflösen und Aufblitzen zurück (Gegner aus dem Pool, AP3)
##   loot_dropped / loot_picked_up → Lichtsäule nach Seltenheit an und aus
##   skill_cast     → Effekt aus SkillDef.vfx_key (AP5), außer bei Skills, deren Effekt erst
##                    im Treffermoment kommt (SKILLS_FROM_CAST). Den ruft AP5 selbst über
##                    Vfx.spawn("<vfx_key>_hit") auf, siehe resolve_key().
##   level_unloading, Szenenwechsel → alles wegräumen
##
## Wer selbst Effekte auslösen will: Vfx.spawn(key, position). Schlüssel stehen in
## VfxLibrary.SPECS. Figuren steuern den Treffer-Effekt über das Meta „hit_vfx“ (StringName,
## zum Beispiel &"bone_chips" oder &"sparks") und die Trefferhöhe über „hit_height“ (Meter).

const MAX_PER_KEY := 24
const MAX_NUMBERS := 64
const DISSOLVE_DELAY := 0.6
const DISSOLVE_TIME := 1.2
const FLASH_TIME := 0.14
const DECAL_LIFETIME := 25.0
const DEFAULT_HIT_HEIGHT := 1.1
## Anteil der normalen Treffer, die Blut am Boden hinterlassen.
const BLOOD_DECAL_CHANCE := 0.3
## Skills, deren Effekt an der Figur hängt statt am Zielpunkt.
const SKILLS_AT_CASTER: Array[StringName] = [&"skill_ancients", &"skill_charge", &"skill_whirlwind"]
## Skills, deren Effekt erst im Treffermoment kommt (AP5 ruft dann Vfx.spawn("<vfx_key>_hit")).
## skill_cast startet für sie nichts, sonst käme der Effekt doppelt oder zu früh.
const SKILLS_FROM_CAST: Array[StringName] = [&"skill_leap", &"skill_war_cry"]
## Treffer-Schlüssel aus AP5 („<vfx_key>_hit“ und andere), die einen eigenen Effekt bekommen.
## Andere „…_hit“ nehmen den Effekt ohne „_hit“, kurze Schlüssel werden zu „skill_<Schlüssel>“.
const SPAWN_ALIASES: Dictionary[StringName, StringName] = {
	&"skill_ancients_hit": &"skill_ancients_strike",
	&"ancients": &"skill_ancients_strike",
	&"skill_strike_hit": &"skill_cleave",
	&"skill_charge_hit": &"skill_strike",
	&"fire_ring": &"skill_fire_ring",
}
## Läuft derselbe Skill-Effekt in diesem Umkreis schon kürzer als DEDUPE_AGE, startet spawn()
## keinen zweiten (AP5 und skill_cast im selben Moment, Wirbel-Takte).
const DEDUPE_RADIUS := 2.5
const DEDUPE_AGE := 0.3
const DEDUPE_AGES: Dictionary[StringName, float] = {&"skill_whirlwind": 0.45}

var _free: Dictionary[StringName, Array] = {}
var _active: Array[VfxEffect] = []
var _numbers_free: Array[DamageNumber] = []
var _numbers_active: Array[DamageNumber] = []
var _beams: Dictionary[ItemInstance, LootBeam] = {}
var _decals: Array[Decal] = []
var _flash_material: ShaderMaterial
var _blood_texture: ImageTexture
var _rng := RandomNumberGenerator.new()
var _headless: bool = DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 4711
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = MaterialLibrary.HIT_FLASH_SHADER
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.entity_spawned.connect(restore)
	EventBus.loot_dropped.connect(_on_loot_dropped)
	EventBus.loot_picked_up.connect(remove_loot_beam)
	EventBus.skill_cast.connect(_on_skill_cast)
	EventBus.level_unloading.connect(func(_layout: LevelLayout) -> void: clear())
	Game.scene_changed.connect(func(_name: String) -> void: clear())
	Graphics.quality_applied.connect(func(_quality: int) -> void: clear(true))


## Startet den Effekt key an position. Liefert den Effekt-Knoten (VfxEffect) oder null,
## wenn es den Schlüssel nicht gibt. Treffer-Schlüssel aus AP5 („skill_leap_hit“) gehen auch.
## Skill-Effekte wackeln hier nicht an der Kamera, das macht AP5 selbst (SkillFx.shake).
func spawn(key: StringName, position: Vector3) -> Node3D:
	var resolved := resolve_key(key)
	if resolved == &"":
		return spawn_effect(key, position)
	var is_skill := String(resolved).begins_with("skill_")
	if is_skill:
		var running := _recent_effect(resolved, position)
		if running != null:
			return running
	return spawn_effect(resolved, position, Vector3.ZERO, 1.0, null, not is_skill)


## Schlüssel aus VfxLibrary zu key: key selbst, ein Alias (SPAWN_ALIASES) oder „skill_<key>“.
## Leer, wenn es keinen passenden Effekt gibt.
static func resolve_key(key: StringName) -> StringName:
	if key == &"":
		return &""
	if VfxLibrary.has_effect(key):
		return key
	var alias: StringName = SPAWN_ALIASES.get(key, &"")
	if alias != &"" and VfxLibrary.has_effect(alias):
		return alias
	var text := String(key)
	if text.ends_with("_hit"):
		var base := resolve_key(StringName(text.trim_suffix("_hit")))
		if base != &"":
			return base
	var prefixed := StringName("skill_%s" % text)
	return prefixed if VfxLibrary.has_effect(prefixed) else &""


## Wie spawn(), mit Richtung (Blut und Funken fliegen weg vom Angreifer), Größe und einer
## Figur, der der Effekt folgt.
func spawn_effect(
	key: StringName,
	position: Vector3,
	direction: Vector3 = Vector3.ZERO,
	scale_factor: float = 1.0,
	follow: Node3D = null,
	with_shake: bool = true
) -> VfxEffect:
	if not VfxLibrary.has_effect(key):
		push_warning("Vfx: unbekannter Effekt '%s'." % key)
		return null
	var effect := _take(key)
	effect.play(position, direction, scale_factor, follow)
	var shake := VfxLibrary.shake_for(key) if with_shake else []
	if not shake.is_empty():
		var rig := CameraRig.get_active()
		if rig != null:
			rig.shake(shake[0], shake[1])
	return effect


## Anzahl laufender Effekte (optional nur eines Schlüssels).
func active_count(key: StringName = &"") -> int:
	if key == &"":
		return _active.size()
	return _active.filter(func(e: VfxEffect) -> bool: return e.key == key).size()


## Anzahl freier Effekte im Pool eines Schlüssels.
func pooled_count(key: StringName) -> int:
	return _free.get(key, []).size()


## Schadenszahl an at.
func show_damage_number(
	at: Vector3,
	amount: float,
	crit: bool = false,
	to_player: bool = false,
	type: Enums.DamageType = Enums.DamageType.PHYSICAL
) -> DamageNumber:
	var number: DamageNumber
	if not _numbers_free.is_empty():
		number = _numbers_free.pop_back()
	elif _numbers_active.size() >= MAX_NUMBERS:
		number = _numbers_active.pop_front()
		number.stop()
		_numbers_free.erase(number)
	else:
		number = DamageNumber.new()
		number.finished.connect(_on_number_finished)
		add_child(number)
	_numbers_active.append(number)
	number.show_damage(at, amount, crit, to_player, type)
	return number


func active_numbers() -> Array[DamageNumber]:
	return _numbers_active


## Lässt eine Figur kurz hell aufblitzen (zusätzlicher Durchgang über ihren Meshes).
func flash(entity: Node3D, strength: float = 1.0) -> void:
	# Ohne Grafik (headless) kennt der Dummy-Renderer keine Instanz-Uniforms.
	if not is_instance_valid(entity) or _headless:
		return
	for mesh in _visible_meshes(entity):
		if mesh.material_overlay != null and mesh.material_overlay != _flash_material:
			continue
		mesh.material_overlay = _flash_material
		mesh.set_instance_shader_parameter(&"flash", strength)
		var tween := mesh.create_tween()
		tween.set_ignore_time_scale(true)
		tween.tween_method(
			func(v: float) -> void: mesh.set_instance_shader_parameter(&"flash", v),
			strength,
			0.0,
			FLASH_TIME
		)
		tween.tween_callback(
			func() -> void:
				if mesh.material_overlay == _flash_material:
					mesh.material_overlay = null
		)


## Löst eine Figur auf. Ist ihr Modell schon ausgeblendet, löst sich eine Kopie auf.
## Liefert die Meshes, die sich auflösen.
func dissolve(
	entity: Node3D, delay: float = DISSOLVE_DELAY, duration: float = DISSOLVE_TIME
) -> Array[MeshInstance3D]:
	if not is_instance_valid(entity):
		return []
	var meshes := _visible_meshes(entity)
	if meshes.is_empty():
		meshes = _ghost_copy(entity)
		delay = 0.0
	var materials: Array[ShaderMaterial] = []
	for mesh in meshes:
		if not mesh.has_meta(&"ap1_prev_override"):
			mesh.set_meta(&"ap1_prev_override", mesh.material_override)
		var material := _dissolve_material_for(mesh)
		mesh.material_override = material
		materials.append(material)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_method(
		func(v: float) -> void:
			for material in materials:
				material.set_shader_parameter(&"progress", v),
		0.0,
		1.0,
		duration
	)
	tween.tween_callback(
		func() -> void:
			for mesh in meshes:
				if is_instance_valid(mesh) and mesh.has_meta(&"ap1_ghost"):
					mesh.queue_free()
	)
	return meshes


## Setzt Auflösen und Aufblitzen einer Figur zurück (Wiederverwendung aus einem Pool).
func restore(entity: Node3D) -> void:
	if not is_instance_valid(entity):
		return
	for node in entity.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.has_meta(&"ap1_prev_override"):
			mesh.material_override = mesh.get_meta(&"ap1_prev_override")
			mesh.remove_meta(&"ap1_prev_override")
		if mesh.material_overlay == _flash_material:
			mesh.material_overlay = null


## Blutfleck am Boden unter position (die Höhe wird auf den Boden gesetzt).
func add_blood_decal(position: Vector3, size: float = 1.6) -> Decal:
	var budget := Graphics.get_preset().max_decals
	if budget <= 0:
		return null
	var decal: Decal
	if _decals.size() >= budget:
		decal = _decals.pop_front()
	else:
		decal = Decal.new()
		decal.name = "BloodDecal"
		decal.texture_albedo = _blood_decal_texture()
		decal.cull_mask = 1
		decal.upper_fade = 0.3
		decal.lower_fade = 0.3
		decal.albedo_mix = 0.9
		add_child(decal)
	_decals.append(decal)
	decal.size = Vector3(size, 0.8, size) * _rng.randf_range(0.7, 1.3)
	decal.global_position = Vector3(position.x, 0.0, position.z)
	decal.rotation = Vector3(0, _rng.randf() * TAU, 0)
	decal.modulate = Color(0.55, 0.05, 0.04, 0.95)
	decal.visible = true
	var tween := decal.create_tween()
	tween.tween_interval(DECAL_LIFETIME)
	tween.tween_property(decal, "modulate:a", 0.0, 3.0)
	return decal


func decal_count() -> int:
	return _decals.size()


## Lichtsäule über Beute. Liefert null für Seltenheiten ohne Leuchten.
func add_loot_beam(item: ItemInstance, position: Vector3) -> LootBeam:
	if item == null or not LootBeam.wants_beam(item.rarity):
		return null
	remove_loot_beam(item)
	var beam := LootBeam.new()
	beam.name = "LootBeam"
	beam.setup(item, item.rarity)
	add_child(beam)
	beam.global_position = position
	_beams[item] = beam
	return beam


func remove_loot_beam(item: ItemInstance) -> void:
	if _beams.has(item):
		var beam := _beams[item]
		_beams.erase(item)
		if is_instance_valid(beam):
			beam.queue_free()


func loot_beam_count() -> int:
	return _beams.size()


## Räumt alle laufenden Effekte, Zahlen, Decals und Säulen weg. pools: auch die Pools leeren
## (nach einem Wechsel der Grafikstufe, damit die Partikelmenge neu gilt).
func clear(pools: bool = false) -> void:
	for effect in _active.duplicate():
		effect.stop()
	for number in _numbers_active.duplicate():
		number.stop()
	for beam in _beams.values():
		if is_instance_valid(beam):
			beam.queue_free()
	_beams.clear()
	for decal in _decals:
		decal.queue_free()
	_decals.clear()
	if pools:
		for key in _free:
			for effect: VfxEffect in _free[key]:
				effect.queue_free()
		_free.clear()


## Schlüssel des Treffer-Effekts für eine Figur und Schadensart.
static func hit_key_for(target: Node, type: Enums.DamageType) -> StringName:
	match type:
		Enums.DamageType.FIRE:
			return &"fire_hit"
		Enums.DamageType.COLD:
			return &"cold_hit"
		Enums.DamageType.POISON:
			return &"poison_hit"
	if target != null and target.has_meta(&"hit_vfx"):
		return StringName(target.get_meta(&"hit_vfx"))
	if target != null and _looks_like_skeleton(target):
		return &"bone_chips"
	return &"blood"


## Effekt-Schlüssel eines Skills: SkillDef.vfx_key, sonst aus dem Verhalten (AP5).
static func skill_key_for(skill: SkillDef) -> StringName:
	if skill == null:
		return &""
	if skill.vfx_key != &"":
		var prefixed := StringName("skill_%s" % skill.vfx_key)
		return prefixed if VfxLibrary.has_effect(prefixed) else skill.vfx_key
	var guess := StringName("skill_%s" % skill.behavior) if skill.behavior != &"" else &""
	if VfxLibrary.has_effect(guess):
		return guess
	for tag in skill.tags:
		var by_tag := StringName("skill_%s" % tag)
		if VfxLibrary.has_effect(by_tag):
			return by_tag
	return &""


func _take(key: StringName) -> VfxEffect:
	var pool: Array = _free.get(key, [])
	var effect: VfxEffect
	if not pool.is_empty():
		effect = pool.pop_back()
	elif active_count(key) >= MAX_PER_KEY:
		for candidate in _active:
			if candidate.key == key:
				effect = candidate
				break
		_active.erase(effect)
		effect.stop()
		_free[key].erase(effect)
	else:
		effect = VfxLibrary.build(key, Graphics.get_preset().particle_amount)
		effect.finished.connect(_on_effect_finished)
		add_child(effect)
	_active.append(effect)
	return effect


func _on_effect_finished(effect: VfxEffect) -> void:
	_active.erase(effect)
	if not _free.has(effect.key):
		_free[effect.key] = []
	if not _free[effect.key].has(effect):
		_free[effect.key].append(effect)


func _on_number_finished(number: DamageNumber) -> void:
	_numbers_active.erase(number)
	if not _numbers_free.has(number):
		_numbers_free.append(number)


func _on_damage_dealt(hit: HitInfo, result: DamageResult) -> void:
	if hit == null or result == null or result.amount <= 0.0:
		return
	var target := hit.target
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var height: float = target.get_meta(&"hit_height", DEFAULT_HIT_HEIGHT)
	var at := target.global_position + Vector3(0, height, 0)
	var direction := Vector3.ZERO
	if is_instance_valid(hit.source) and hit.source.is_inside_tree():
		direction = target.global_position - hit.source.global_position
	var to_player := target == Game.player
	show_damage_number(at + Vector3(0, 0.6, 0), result.amount, result.crit, to_player, hit.type)
	var key := hit_key_for(target, hit.type)
	var size := 1.4 if result.crit or result.killed else 1.0
	spawn_effect(key, at - Vector3(0, 0.9, 0), direction, size)
	if hit.type == Enums.DamageType.PHYSICAL and key != &"blood":
		spawn_effect(&"hit", at - Vector3(0, 0.9, 0), direction, size)
	if result.crit:
		spawn_effect(&"crit", at - Vector3(0, 0.9, 0), direction)
	flash(target, 1.4 if result.crit else 1.0)
	if key == &"blood" and (result.killed or _rng.randf() < BLOOD_DECAL_CHANCE):
		add_blood_decal(target.global_position + direction.normalized() * 0.6, 1.2)


func _on_entity_died(entity: Node3D, _killer: Node3D) -> void:
	if not is_instance_valid(entity) or not entity.is_inside_tree() or entity == Game.player:
		return
	spawn_effect(&"death_burst", entity.global_position)
	dissolve(entity)
	if hit_key_for(entity, Enums.DamageType.PHYSICAL) == &"blood":
		add_blood_decal(entity.global_position, 2.2)


func _on_loot_dropped(item: ItemInstance, position: Vector3) -> void:
	add_loot_beam(item, position)


func _on_skill_cast(caster: Node3D, skill: SkillDef, target_position: Vector3) -> void:
	var key := skill_key_for(skill)
	if key == &"" or not VfxLibrary.has_effect(key) or SKILLS_FROM_CAST.has(key):
		return
	var caster_ok := is_instance_valid(caster) and caster.is_inside_tree()
	var at_caster := SKILLS_AT_CASTER.has(key) and caster_ok
	var position := caster.global_position if at_caster else target_position
	var direction := Vector3.ZERO
	if caster_ok:
		direction = target_position - caster.global_position
	var follow := caster if key == &"skill_whirlwind" and caster_ok else null
	if _recent_effect(key, position) == null:
		spawn_effect(key, position, direction, 1.0, follow)


## Ein laufender Effekt key nahe position, der jünger ist als seine Doppel-Sperre, sonst null.
func _recent_effect(key: StringName, position: Vector3) -> VfxEffect:
	var max_age: float = DEDUPE_AGES.get(key, DEDUPE_AGE)
	for effect in _active:
		if (
			effect.key == key
			and effect.get_age() < max_age
			and effect.global_position.distance_to(position) < DEDUPE_RADIUS
		):
			return effect
	return null


## Sichtbare Meshes einer Figur (ohne Effekte, Beschriftungen und Vorwarnungen).
func _visible_meshes(entity: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in entity.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.is_visible_in_tree() and mesh.mesh != null and not mesh.is_in_group(&"no_vfx"):
			result.append(mesh)
	return result


## Kopie der Meshes einer ausgeblendeten Figur an ihrer letzten Stelle (für das Auflösen).
func _ghost_copy(entity: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in entity.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		if not source.visible or source.mesh == null or source.is_in_group(&"no_vfx"):
			continue
		var ghost := MeshInstance3D.new()
		ghost.name = "DissolveGhost"
		ghost.set_meta(&"ap1_ghost", true)
		if source.skin != null and source.get_node_or_null(source.skeleton) != null:
			ghost.mesh = source.bake_mesh_from_current_skeleton_pose()
		else:
			ghost.mesh = source.mesh
		ghost.material_override = source.material_override
		if ghost.material_override == null and source.mesh.get_surface_count() > 0:
			ghost.material_override = source.get_active_material(0)
		add_child(ghost)
		ghost.global_transform = source.global_transform
		result.append(ghost)
	return result


func _dissolve_material_for(mesh: MeshInstance3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MaterialLibrary.DISSOLVE_SHADER
	material.set_shader_parameter(&"noise_texture", MaterialLibrary.dissolve_noise())
	var source: Material = mesh.material_override
	if source == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		source = mesh.get_active_material(0)
	var base := source as BaseMaterial3D
	if base != null:
		material.set_shader_parameter(&"albedo_color", base.albedo_color)
		if base.albedo_texture != null:
			material.set_shader_parameter(&"albedo_texture", base.albedo_texture)
		material.set_shader_parameter(&"roughness", base.roughness)
	return material


func _blood_decal_texture() -> ImageTexture:
	if _blood_texture != null:
		return _blood_texture
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var blobs: Array[Vector3] = [Vector3(64, 64, 26)]
	for i in 18:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(10.0, 50.0)
		blobs.append(
			Vector3(64 + cos(angle) * dist, 64 + sin(angle) * dist, rng.randf_range(3.0, 12.0))
		)
	for y in size:
		for x in size:
			var alpha := 0.0
			for blob in blobs:
				var d := Vector2(x, y).distance_to(Vector2(blob.x, blob.y))
				alpha = maxf(alpha, clampf((blob.z - d) / 3.0, 0.0, 1.0))
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	image.generate_mipmaps()
	_blood_texture = ImageTexture.create_from_image(image)
	return _blood_texture


static func _looks_like_skeleton(target: Node) -> bool:
	var names := "%s %s" % [target.name, target.scene_file_path]
	for child in target.get_children():
		names += " " + child.scene_file_path
	return names.to_lower().contains("skelet")
