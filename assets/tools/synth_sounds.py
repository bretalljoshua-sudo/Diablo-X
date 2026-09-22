#!/usr/bin/env python3
"""Erzeugt die eigenen Klänge von AP8 (Schritte, Schwünge, Treffer, Beute) als WAV.

Aufruf aus dem Projektordner:  python3 assets/tools/synth_sounds.py
Braucht nur numpy. Der Zufall ist fest gesetzt, das Ergebnis also immer gleich.
Alle Klänge sind eigene Werke und stehen wie der Rest der Assets unter CC0.
"""

import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "audio" / "synth"
rng = np.random.default_rng(8)


def _time(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def _lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    # Einfacher Tiefpass erster Ordnung, zweimal angewendet.
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    out = signal.copy()
    for _ in range(2):
        acc = 0.0
        for i, value in enumerate(out):
            acc += alpha * (value - acc)
            out[i] = acc
    return out


def _highpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    return signal - _lowpass(signal, cutoff)


def _sweep_lowpass(signal: np.ndarray, start: float, end: float) -> np.ndarray:
    # Tiefpass mit wanderndem Knick (für Schwünge).
    cutoffs = np.geomspace(start, end, len(signal))
    alphas = 1.0 - np.exp(-2.0 * np.pi * cutoffs / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, value in enumerate(signal):
        acc += alphas[i] * (value - acc)
        out[i] = acc
    return out


def _save(name: str, signal: np.ndarray, peak: float = 0.8) -> None:
    signal = signal / max(np.max(np.abs(signal)), 1e-9) * peak
    fade = min(len(signal), int(RATE * 0.005))
    signal[-fade:] *= np.linspace(1.0, 0.0, fade)
    data = (signal * 32767).astype("<i2").tobytes()
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(data)


def footstep(index: int) -> None:
    # Stiefel auf Stein: dumpfer Aufsatz und kurzes Kratzen.
    t = _time(0.16)
    thump = np.sin(2 * np.pi * (70 + 15 * index) * t) * np.exp(-t * 60)
    scuff = _lowpass(rng.normal(size=len(t)), 1800 + 300 * index) * np.exp(-t * 35)
    grit = _highpass(rng.normal(size=len(t)), 3000) * np.exp(-t * 90) * 0.15
    _save(f"footstep_{index}", thump * 0.6 + scuff * 1.2 + grit, 0.7)


def swing(index: int) -> None:
    # Waffe schneidet durch die Luft: Rauschen mit auf- und abschwellendem Filter.
    length = 0.28 + 0.04 * index
    t = _time(length)
    envelope = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 2
    noise = rng.normal(size=len(t))
    whoosh = _sweep_lowpass(noise, 300 + 100 * index, 2600) * envelope
    _save(f"swing_{index}", whoosh, 0.6)


def impact(index: int) -> None:
    # Treffer: tiefer Schlag, Knacken und kurzes Rauschen.
    t = _time(0.3)
    pitch = 110 - 15 * index
    body = np.sin(2 * np.pi * pitch * t * (1 - 0.4 * t)) * np.exp(-t * 18)
    crack = _highpass(rng.normal(size=len(t)), 1500) * np.exp(-t * 70)
    flesh = _lowpass(rng.normal(size=len(t)), 900) * np.exp(-t * 25)
    _save(f"impact_{index}", body * 1.0 + crack * 0.5 + flesh * 0.8, 0.9)


def _bell(t: np.ndarray, base: float, decay: float) -> np.ndarray:
    partials = [(1.0, 1.0), (2.0, 0.5), (2.76, 0.35), (5.4, 0.2), (8.93, 0.1)]
    out = np.zeros_like(t)
    for ratio, gain in partials:
        out += gain * np.sin(2 * np.pi * base * ratio * t) * np.exp(-t * decay * ratio**0.5)
    return out


def loot_rare() -> None:
    # Seltene Beute: zwei helle Glockentöne mit Schimmer.
    t = _time(1.4)
    first = _bell(t, 880, 3.5)
    second = np.zeros_like(t)
    offset = int(RATE * 0.12)
    second[offset:] = _bell(t[: len(t) - offset], 1318.5, 3.5)
    shimmer = _highpass(rng.normal(size=len(t)), 5000) * np.exp(-t * 6) * 0.08
    _save("loot_drop_rare", first + second * 0.8 + shimmer, 0.6)


def loot_legendary() -> None:
    # Legendäre Beute: tiefer Gong, darüber ein aufsteigender Dreiklang.
    t = _time(2.4)
    gong = _bell(t, 196, 1.2) * 1.2
    chord = np.zeros_like(t)
    for step, freq in enumerate([587.3, 740.0, 880.0, 1174.7]):
        offset = int(RATE * (0.15 + 0.1 * step))
        chord[offset:] += _bell(t[: len(t) - offset], freq, 2.5) * 0.5
    swell = _highpass(rng.normal(size=len(t)), 4000) * np.sin(np.pi * t / 2.4) * 0.05
    _save("loot_drop_legendary", gong + chord + swell, 0.7)


def main() -> None:
    for index in range(1, 5):
        footstep(index)
    for index in range(1, 4):
        swing(index)
        impact(index)
    loot_rare()
    loot_legendary()
    print("Klänge geschrieben nach", OUT)


if __name__ == "__main__":
    main()
