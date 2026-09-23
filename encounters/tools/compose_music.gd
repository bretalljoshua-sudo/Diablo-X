extends SceneTree
## Erzeugt die Musik von Version 0.1 aus Godot-Bordmitteln (reine Synthese, keine fremden Aufnahmen)
## und schreibt sie als nahtlose Schleifen nach assets/audio/music/*.wav.
##
## Aufruf (einmalig, das Ergebnis liegt im Repo):
##   godot --headless --path . -s res://encounters/tools/compose_music.gd
##
## Stücke:
##   village    Dorf und Titelbildschirm: ruhige Harfe (Karplus-Strong) über warmen Flächen, a-Moll
##   catacombs  Katakomben: tiefer Bordun, dunkle Flächen, ferne Glocken, dumpfe Schläge, d-Moll
##   boss       Bosskampf: Trommeln, treibendes Bass-Ostinato, Bläserstöße, e-Moll, 120 Schläge/min
##
## Alles ist fest geseedet, das Ergebnis ist also immer gleich. Lizenz: CC0 wie die übrigen Assets.

const RATE := 22050
const OUT_DIR := "res://assets/audio/music"
const TAIL := 3.0

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_write("village", _village())
	_write("catacombs", _catacombs())
	_write("boss", _boss())
	quit()


# --- Stücke ------------------------------------------------------------------------------------


func _village() -> PackedFloat32Array:
	_rng.seed = 11
	var length := 36.0
	var buf := _buffer(length)
	var wet := _buffer(length)
	# a-Moll, F-Dur, C-Dur, G-Dur, je 9 s.
	var chords: Array = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
	var beat := 60.0 / 80.0
	for c in chords.size():
		var start := c * 9.0
		var chord: Array = chords[c]
		for note: int in chord:
			_pad(buf, start, 9.0, _freq(note - 12), 0.05, 2.5, &"triangle", 700.0)
		_pad(buf, start, 9.0, _freq(chord[0] - 24), 0.07, 2.0, &"sine", 400.0)
		# Harfe: Achtel über die Akkordtöne, auf und ab.
		var pattern := [0, 1, 2, 3, 2, 1, 0, 2]
		var steps := int(9.0 / (beat * 0.5))
		for s in steps:
			var index: int = pattern[s % pattern.size()]
			var note: int = chord[index % 3] + (12 if index == 3 else 0)
			if _rng.randf() < 0.18:
				continue
			var gain := 0.16 if s % 4 == 0 else 0.11
			_pluck(wet, start + s * beat * 0.5, _freq(note), gain, 2.2)
		# Eine leise Melodienote je Takt.
		for bar in 3:
			var note: int = chord[_rng.randi_range(0, 2)] + 12
			_pluck(wet, start + bar * 3.0 + beat * 1.5, _freq(note), 0.09, 3.0)
	_noise_wind(buf, length, 0.012)
	_add(buf, _reverb(wet, 0.35))
	_add(buf, wet, 0.8)
	return _finish(buf, length, 0.9)


func _catacombs() -> PackedFloat32Array:
	_rng.seed = 23
	var length := 36.0
	var buf := _buffer(length)
	var wet := _buffer(length)
	# d-Moll, B-Dur, g-Moll, A-Dur, je 9 s.
	var chords: Array = [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]]
	_drone(buf, length, _freq(38), 0.16)
	for c in chords.size():
		var start := c * 9.0
		for note: int in chords[c]:
			_pad(wet, start, 9.0, _freq(note), 0.035, 3.0, &"saw", 650.0)
	# Glocken aus der d-Moll-Tonleiter, unregelmäßig, dazu dumpfe Schläge.
	var scale := [62, 65, 67, 69, 70, 72, 74]
	var t := 1.5
	while t < length - 1.0:
		_bell(wet, t, _freq(scale[_rng.randi_range(0, scale.size() - 1)]), 0.12, 4.0)
		t += _rng.randf_range(2.2, 4.2)
	var thump := 0.0
	while thump < length:
		_kick(buf, thump, 0.35, 55.0, 32.0, 0.6)
		_kick(buf, thump + 0.45, 0.2, 52.0, 30.0, 0.5)
		thump += 4.5
	_add(buf, _reverb(wet, 0.5))
	_add(buf, wet, 0.6)
	_noise_wind(buf, length, 0.02)
	return _finish(buf, length, 0.9)


func _boss() -> PackedFloat32Array:
	_rng.seed = 37
	var bpm := 120.0
	var beat := 60.0 / bpm
	var bars := 16
	var length := bars * 4 * beat
	var buf := _buffer(length)
	var wet := _buffer(length)
	# e-Moll, C-Dur, D-Dur, H-Dur je Takt, viermal.
	var roots := [40, 36, 38, 35]
	var thirds := [43, 40, 42, 39]
	var fifths := [47, 43, 45, 42]
	var ostinato := [0, 0, 12, 0, 7, 0, 10, 7]
	for bar in bars:
		var start := bar * 4 * beat
		var chord := bar % 4
		var root: int = roots[chord]
		# Trommeln: Pauke auf 1 und 3, dazu Synkopen, Rauschschlag auf 2 und 4.
		_kick(buf, start, 0.55, 75.0, 38.0, 0.45)
		_kick(buf, start + 2 * beat, 0.5, 75.0, 38.0, 0.45)
		_kick(buf, start + 3.5 * beat, 0.35, 70.0, 40.0, 0.3)
		if bar % 2 == 1:
			_kick(buf, start + 1.5 * beat, 0.3, 70.0, 40.0, 0.3)
		_snare(buf, start + beat, 0.22)
		_snare(buf, start + 3 * beat, 0.26)
		if bar % 4 == 3:
			for roll in 4:
				_snare(buf, start + 3.5 * beat + roll * beat * 0.125, 0.1 + roll * 0.04)
		# Bass-Ostinato in Achteln.
		for step in 8:
			var note: int = root + int(ostinato[step]) - 12
			_bass(buf, start + step * beat * 0.5, beat * 0.45, _freq(note), 0.2)
		# Bläserstoß am Taktanfang, Chorfläche darüber.
		for note: int in [root + 12, int(thirds[chord]) + 12, int(fifths[chord]) + 12]:
			_brass(wet, start, beat * 1.4, _freq(note), 0.07)
			_pad(wet, start, 4 * beat, _freq(note + 12), 0.025, 0.4, &"sine", 2000.0)
		if bar >= 8:
			# Zweite Hälfte: Gegenstimme in Vierteln.
			for q in 4:
				var high: int = [
					root + 24, int(fifths[chord]) + 12, int(thirds[chord]) + 12, root + 19
				][q]
				_brass(wet, start + q * beat, beat * 0.8, _freq(high), 0.035)
	_add(buf, _reverb(wet, 0.3))
	_add(buf, wet, 0.8)
	return _finish(buf, length, 0.95)


# --- Klangbausteine ----------------------------------------------------------------------------


func _buffer(length: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int((length + TAIL) * RATE))
	return buf


func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Fläche mit weichem Ein- und Ausblenden, leicht verstimmt, durch einen Tiefpass.
func _pad(
	buf: PackedFloat32Array,
	start: float,
	duration: float,
	freq: float,
	gain: float,
	fade: float,
	wave: StringName,
	cutoff: float
) -> void:
	var from := int(start * RATE)
	var total := int((duration + fade) * RATE)
	var alpha := 1.0 - exp(-TAU * cutoff / RATE)
	var low := 0.0
	var phases := [0.0, 0.0, 0.0]
	var detune := [1.0, 1.004, 0.9965]
	for i in total:
		var t := float(i) / RATE
		var env := minf(t / fade, 1.0)
		if t > duration:
			env *= maxf(1.0 - (t - duration) / fade, 0.0)
		var value := 0.0
		for v in 3:
			phases[v] = fmod(phases[v] + freq * detune[v] / RATE, 1.0)
			value += _wave(wave, phases[v])
		low += alpha * (value / 3.0 - low)
		var index := from + i
		if index < buf.size():
			buf[index] += low * env * gain


func _wave(wave: StringName, phase: float) -> float:
	match wave:
		&"saw":
			return phase * 2.0 - 1.0
		&"triangle":
			return 1.0 - 4.0 * absf(phase - 0.5)
		_:
			return sin(phase * TAU)


## Gezupfte Saite (Karplus-Strong).
func _pluck(buf: PackedFloat32Array, start: float, freq: float, gain: float, length: float) -> void:
	var period := maxi(int(RATE / freq), 2)
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = _rng.randf_range(-1.0, 1.0)
	var from := int(start * RATE)
	var total := int(length * RATE)
	var index := 0
	var damping := 0.996
	for i in total:
		var next := (index + 1) % period
		var value := ring[index]
		ring[index] = (value + ring[next]) * 0.5 * damping
		index = next
		var out := from + i
		if out < buf.size():
			buf[out] += value * gain * (1.0 - float(i) / total)


## Glocke: Teiltöne mit Abstand wie bei einer Kirchenglocke, lange Abklingzeit.
func _bell(buf: PackedFloat32Array, start: float, freq: float, gain: float, length: float) -> void:
	var partials := [[1.0, 1.0], [2.0, 0.5], [2.76, 0.35], [5.4, 0.2], [0.5, 0.3]]
	var from := int(start * RATE)
	var total := int(length * RATE)
	for i in total:
		var t := float(i) / RATE
		var value := 0.0
		for p: Array in partials:
			value += sin(TAU * freq * p[0] * t) * p[1] * exp(-t * (1.2 + p[0] * 0.4))
		var out := from + i
		if out < buf.size():
			buf[out] += value * gain * minf(t * 200.0, 1.0)


## Tiefer Schlag mit fallender Tonhöhe (Pauke, Herzschlag).
func _kick(
	buf: PackedFloat32Array, start: float, gain: float, high: float, low: float, decay: float
) -> void:
	var from := int(start * RATE)
	var total := int(decay * 2.5 * RATE)
	var phase := 0.0
	for i in total:
		var t := float(i) / RATE
		var freq := low + (high - low) * exp(-t * 18.0)
		phase += freq / RATE
		var value := sin(phase * TAU) * exp(-t / decay * 2.2)
		var out := from + i
		if out < buf.size():
			buf[out] += value * gain


## Rauschschlag (Trommelfell mit Schnarren), gefiltert.
func _snare(buf: PackedFloat32Array, start: float, gain: float) -> void:
	var from := int(start * RATE)
	var total := int(0.3 * RATE)
	var low := 0.0
	var alpha := 1.0 - exp(-TAU * 2500.0 / RATE)
	for i in total:
		var t := float(i) / RATE
		low += alpha * (_rng.randf_range(-1.0, 1.0) - low)
		var body := sin(TAU * 180.0 * t) * exp(-t * 30.0)
		var value := (low * 0.8 + body * 0.5) * exp(-t * 14.0)
		var out := from + i
		if out < buf.size():
			buf[out] += value * gain


## Bass: Sägezahn mit Filterhüllkurve.
func _bass(
	buf: PackedFloat32Array, start: float, duration: float, freq: float, gain: float
) -> void:
	var from := int(start * RATE)
	var total := int((duration + 0.05) * RATE)
	var phase := 0.0
	var low := 0.0
	for i in total:
		var t := float(i) / RATE
		phase = fmod(phase + freq / RATE, 1.0)
		var cutoff := 200.0 + 1400.0 * exp(-t * 12.0)
		var alpha := 1.0 - exp(-TAU * cutoff / RATE)
		low += alpha * ((phase * 2.0 - 1.0) - low)
		var env := (
			minf(t * 300.0, 1.0) * (1.0 if t < duration else maxf(1.0 - (t - duration) * 20.0, 0.0))
		)
		var out := from + i
		if out < buf.size():
			buf[out] += low * env * gain


## Bläserstoß: zwei verstimmte Sägezähne, Filter öffnet sich kurz.
func _brass(
	buf: PackedFloat32Array, start: float, duration: float, freq: float, gain: float
) -> void:
	var from := int(start * RATE)
	var total := int((duration + 0.4) * RATE)
	var a := 0.0
	var b := 0.0
	var low := 0.0
	for i in total:
		var t := float(i) / RATE
		a = fmod(a + freq / RATE, 1.0)
		b = fmod(b + freq * 1.006 / RATE, 1.0)
		var cutoff := 500.0 + 2200.0 * minf(t * 12.0, 1.0) * exp(-t * 2.5)
		var alpha := 1.0 - exp(-TAU * cutoff / RATE)
		low += alpha * ((a + b - 1.0) - low)
		var env := minf(t * 40.0, 1.0)
		if t > duration:
			env *= maxf(1.0 - (t - duration) / 0.4, 0.0)
		var out := from + i
		if out < buf.size():
			buf[out] += low * env * gain


## Tiefer Bordun mit langsamem Schweben über die ganze Länge (schleifengerecht).
func _drone(buf: PackedFloat32Array, length: float, freq: float, gain: float) -> void:
	var total := int(length * RATE)
	var low := 0.0
	var alpha := 1.0 - exp(-TAU * 260.0 / RATE)
	# Frequenzen auf ganze Schwingungen je Schleife runden, damit die Naht nicht knackt.
	var f1 := roundf(freq * length) / length
	var f2 := roundf(freq * 1.5 * length) / length
	var wobble := 2.0 / length
	for i in total + int(TAIL * RATE):
		var t := float(i) / RATE
		var saw := fmod(f1 * t, 1.0) * 2.0 - 1.0
		low += alpha * (saw - low)
		var value := sin(TAU * f1 * t) * 0.7 + low * 0.5 + sin(TAU * f2 * t) * 0.15
		value *= 0.8 + 0.2 * sin(TAU * wobble * t)
		if i < buf.size():
			buf[i] += value * gain


func _noise_wind(buf: PackedFloat32Array, length: float, gain: float) -> void:
	var low := 0.0
	var alpha := 1.0 - exp(-TAU * 350.0 / RATE)
	var sway := 3.0 / length
	for i in int(length * RATE):
		low += alpha * (_rng.randf_range(-1.0, 1.0) - low)
		var t := float(i) / RATE
		buf[i] += low * gain * (0.6 + 0.4 * sin(TAU * sway * t))


## Einfacher Hall (Schroeder: vier Kammfilter, zwei Allpässe).
func _reverb(source: PackedFloat32Array, mix: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(source.size())
	var combs := [1557, 1617, 1491, 1422]
	var feedback := 0.8
	for delay: int in combs:
		var line := PackedFloat32Array()
		line.resize(delay)
		var index := 0
		for i in source.size():
			var y := line[index]
			line[index] = source[i] + y * feedback
			index = (index + 1) % delay
			out[i] += y * 0.25
	for delay: int in [225, 556]:
		var line := PackedFloat32Array()
		line.resize(delay)
		var index := 0
		for i in out.size():
			var buffered := line[index]
			var x := out[i]
			line[index] = x + buffered * 0.5
			out[i] = buffered - x * 0.5
			index = (index + 1) % delay
	for i in out.size():
		out[i] *= mix
	return out


func _add(target: PackedFloat32Array, source: PackedFloat32Array, gain: float = 1.0) -> void:
	for i in mini(target.size(), source.size()):
		target[i] += source[i] * gain


## Legt den Nachhall hinter dem Schleifenende auf den Anfang (nahtlos) und normalisiert.
func _finish(buf: PackedFloat32Array, length: float, peak: float) -> PackedFloat32Array:
	var total := int(length * RATE)
	var result := PackedFloat32Array()
	result.resize(total)
	for i in total:
		result[i] = buf[i]
	for i in range(total, buf.size()):
		result[i - total] += buf[i]
	var loudest := 0.0001
	for value in result:
		loudest = maxf(loudest, absf(value))
	var scale := peak / loudest
	for i in total:
		# Sanfte Sättigung gegen Spitzen.
		result[i] = tanh(result[i] * scale * 1.1) / tanh(1.1)
	return result


func _write(track: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	var path := "%s/%s.wav" % [OUT_DIR, track]
	var err := stream.save_to_wav(path)
	print("Musik: %s (%.1f s, %s)" % [path, samples.size() / float(RATE), error_string(err)])
