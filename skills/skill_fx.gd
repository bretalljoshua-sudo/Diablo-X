class_name SkillFx
## Kamerawackeln, Effekte und Animationen für Skills, jeweils mit Rückfall:
## - Wackeln über CameraRig.shake(), solange es eine Kamera gibt (AP1 ersetzt das Rig).
## - Effekte über den Autoload „Vfx“ (AP1) mit spawn(key, position). Liefert er keinen Effekt
##   (noch nicht gebaut), leuchtet stattdessen kurz ein Kreis am Boden auf.
## - Animationen über CharacterModel.play_action() (AP8), ohne Modell passiert nichts.

const PLACEHOLDER_DURATION := 0.35


static func shake(strength: float, duration: float = 0.25) -> void:
	var rig := CameraRig.get_active()
	if rig != null and rig.has_method(&"shake"):
		rig.shake(strength, duration)


## Effekt am Boden. parent ist der Knoten, unter den der Platzhalter kommt (zum Beispiel die
## Ebene der Spielerfigur).
static func spawn(
	parent: Node, key: StringName, position: Vector3, radius: float, color: Color
) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var vfx := parent.get_tree().root.get_node_or_null(^"Vfx")
	if vfx != null and vfx.has_method(&"spawn") and key != &"":
		if vfx.call(&"spawn", key, position) != null:
			return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	disc.material = material
	var instance := MeshInstance3D.new()
	instance.name = &"SkillFx"
	instance.mesh = disc
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.global_position = Vector3(position.x, position.y + 0.06, position.z)
	var tween := instance.create_tween()
	tween.tween_property(material, ^"albedo_color:a", 0.0, PLACEHOLDER_DURATION)
	tween.tween_callback(instance.queue_free)


## Spielt eine Aktion am Modell so, dass sie duration Sekunden dauert (duration <= 0: normales
## Tempo). Liefert den Treffermoment aus der Animation in Sekunden, sonst -1.
static func play(model: Node, action: StringName, duration: float) -> float:
	if model == null or action == &"" or not model.has_method(&"play_action"):
		return -1.0
	var length := 0.0
	if model.has_method(&"get_action_length"):
		length = model.call(&"get_action_length", action)
	var speed := length / duration if length > 0.0 and duration > 0.0 else 1.0
	if not model.call(&"play_action", action, speed):
		return -1.0
	if model.has_method(&"get_event_time"):
		var event_time: float = model.call(&"get_event_time", action, &"hit")
		if event_time >= 0.0:
			return event_time / speed
	return -1.0


## Läuft die Aktion noch? Ohne Modell false.
static func is_playing(model: Node, action: StringName) -> bool:
	return (
		model != null
		and model.has_method(&"get_current_action")
		and model.call(&"get_current_action") == action
	)


static func stop(model: Node) -> void:
	if model != null and model.has_method(&"stop_action"):
		model.call(&"stop_action")
