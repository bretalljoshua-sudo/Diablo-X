class_name PhysicsTickProbe
extends Node
## Misst, wie lange jeder Physik-Takt für die Spiellogik braucht: vom Beginn des Takts
## (SceneTree.physics_frame, vor allen _physics_process) bis nach dem letzten
## _physics_process (dieser Knoten läuft mit der höchsten Priorität zuletzt). Enthalten sind
## alle Skripte, move_and_slide (Physik-Abfragen) und die Wegfindungs-Abfragen.
## Godots eigener Monitor TIME_PHYSICS_PROCESS liefert dagegen nur den größten Takt der letzten
## Sekunde und wird zusätzlich ausgegeben.

var samples_ms: Array[float] = []
var recording: bool = false

var _start_usec: int = 0


func _ready() -> void:
	process_physics_priority = 1000000
	get_tree().physics_frame.connect(_on_physics_frame)


func _on_physics_frame() -> void:
	_start_usec = Time.get_ticks_usec()


func _physics_process(_delta: float) -> void:
	if recording and _start_usec > 0:
		samples_ms.append((Time.get_ticks_usec() - _start_usec) / 1000.0)


func mean() -> float:
	var total := 0.0
	for sample in samples_ms:
		total += sample
	return total / maxf(samples_ms.size(), 1)


func percentile(p: float) -> float:
	if samples_ms.is_empty():
		return 0.0
	var sorted := samples_ms.duplicate()
	sorted.sort()
	return sorted[clampi(int(sorted.size() * p), 0, sorted.size() - 1)]
