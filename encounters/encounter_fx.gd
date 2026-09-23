class_name EncounterFx
extends RefCounted
## Effekte und Kamerawackeln für Boss und Spielablauf, mit Rückfall: fehlt AP1s Kamera-Rig oder ein
## Effekt, passiert einfach nichts (oder es leuchtet ein schlichter Kreis am Boden).


static func shake(strength: float, duration: float) -> void:
	var rig := CameraRig.get_active()
	if rig != null:
		rig.shake(strength, duration)


## Startet einen Effekt aus AP1s Bibliothek (Vfx.spawn). Liefert null, wenn es ihn nicht gibt.
static func spawn(key: StringName, position: Vector3) -> Node3D:
	return Vfx.spawn(key, position)


## Schlichter Leuchtring am Boden, verblasst in duration Sekunden (Rückfall ohne Effekt).
static func flash_ring(parent: Node, position: Vector3, radius: float, color: Color) -> void:
	if parent == null:
		return
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.8
	mesh.outer_radius = radius
	mesh.rings = 32
	mesh.ring_segments = 4
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	ring.material_override = mat
	parent.add_child(ring)
	ring.global_position = position + Vector3(0, 0.08, 0)
	var tween := ring.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.tween_callback(ring.queue_free)
