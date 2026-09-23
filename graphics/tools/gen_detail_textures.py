#!/usr/bin/env python3
"""Erzeugt die nahtlosen Detail-Texturen für den Baukasten (AP1).

Die KayKit-Modelle haben nur flache Farben aus einer Palette. Der Shader
graphics/shaders/kit_surface.gdshaderinc legt diese Texturen weltbezogen darüber:

  stone_detail.png   R Helligkeit, G Rauheit, B Hohlräume (Fugen, Poren), A Höhe
  stone_normal.png   Normalen (OpenGL, Y nach oben)
  wood_detail.png    wie stone_detail, Maserung und Brettfugen
  wood_normal.png
  macro_noise.png    R Schmutzflecken, G Moos, B Nässe (großflächig, weich)
  decal_stain.png    Fleck für Decals am Boden (Alpha = Deckung, Farbe weiß, getönt im Spiel)
  decal_crack.png    Risse für Decals am Boden

Alles ist periodisch (Spektralsynthese und Worley-Rauschen mit Umbruch), die Texturen kacheln
also ohne Naht. Aufruf: python3 graphics/tools/gen_detail_textures.py (braucht numpy und Pillow).
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
SIZE = 1024


def spectral(n: int, beta: float, seed: int, stretch: tuple[float, float] = (1.0, 1.0),
             low: float = 1.0, high: float | None = None) -> np.ndarray:
    """Periodisches 1/f^beta-Rauschen, normiert auf 0..1."""
    rng = np.random.default_rng(seed)
    white = rng.normal(size=(n, n))
    fy = np.fft.fftfreq(n)[:, None] * n * stretch[1]
    fx = np.fft.fftfreq(n)[None, :] * n * stretch[0]
    radius = np.sqrt(fx * fx + fy * fy)
    amp = 1.0 / np.maximum(radius, low) ** beta
    amp[radius < low * 0.5] = 0.0
    if high is not None:
        amp *= np.exp(-((radius / high) ** 2))
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    field -= field.min()
    return field / max(field.max(), 1e-9)


def worley(n: int, cells: int, seed: int) -> tuple[np.ndarray, np.ndarray]:
    """Periodisches Worley-Rauschen: Abstand zum nächsten (F1) und zweitnächsten Punkt (F2),
    in Zellbreiten."""
    rng = np.random.default_rng(seed)
    points = rng.random((cells, cells, 2))
    coords = (np.arange(n) + 0.5) / n * cells
    gx, gy = np.meshgrid(coords, coords)
    cx = np.floor(gx).astype(int)
    cy = np.floor(gy).astype(int)
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            nx = cx + ox
            ny = cy + oy
            p = points[ny % cells, nx % cells]
            px = nx + p[..., 0]
            py = ny + p[..., 1]
            d = np.sqrt((gx - px) ** 2 + (gy - py) ** 2)
            f2 = np.where(d < f1, f1, np.minimum(f2, d))
            f1 = np.minimum(f1, d)
    return f1, f2


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normal_map(height: np.ndarray, strength: float) -> np.ndarray:
    """Normalen aus einer periodischen Höhe (OpenGL-Konvention)."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    drow = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = drow * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / length, ny / length, nz / length], axis=-1) * 0.5 + 0.5
    return (rgb * 255.0 + 0.5).astype(np.uint8)


def save_rgba(name: str, channels: list[np.ndarray]) -> None:
    data = np.stack([np.clip(c, 0.0, 1.0) for c in channels], axis=-1)
    mode = "RGBA" if len(channels) == 4 else "RGB"
    Image.fromarray((data * 255.0 + 0.5).astype(np.uint8), mode).save(os.path.join(OUT, name))


def stone() -> None:
    n = SIZE
    # Grobe Steinstruktur, feines Korn und Poren.
    body = spectral(n, 1.9, 11, low=2.0)
    grain = spectral(n, 1.2, 12, low=24.0)
    # Haarrisse: dünne Zellränder, nur in einem Teil der Fläche.
    f1, f2 = worley(n, 4, 13)
    edge = f2 - f1
    wobble = spectral(n, 1.6, 14, low=4.0)
    crack_width = 0.01 + 0.012 * wobble
    cracks = 1.0 - smoothstep(0.0, 1.0, edge / crack_width)
    cracks *= smoothstep(0.55, 0.75, spectral(n, 1.4, 15, low=2.0))
    pf1, _ = worley(n, 48, 16)
    pores = 1.0 - smoothstep(0.0, 0.22, pf1)
    pores *= smoothstep(0.45, 0.8, spectral(n, 1.0, 17, low=8.0))
    chips_f1, chips_f2 = worley(n, 14, 18)
    chips = smoothstep(0.0, 0.3, chips_f2 - chips_f1)  # flache Buckel, weiche Ränder
    height = 0.55 * body + 0.22 * grain + 0.05 * chips - 0.3 * cracks - 0.18 * pores
    height = (height - height.min()) / (height.max() - height.min())
    cavity = np.clip(1.0 - 0.9 * cracks - 0.6 * pores, 0.0, 1.0)
    albedo = 0.5 + 0.28 * (body - 0.5) + 0.18 * (grain - 0.5) - 0.25 * cracks - 0.1 * pores
    roughness = 0.72 + 0.18 * (1.0 - body) + 0.1 * cracks - 0.08 * grain
    save_rgba("stone_detail.png", [albedo, roughness, cavity, height])
    Image.fromarray(normal_map(height, 9.0), "RGB").save(os.path.join(OUT, "stone_normal.png"))


def wood() -> None:
    n = SIZE
    # Maserung entlang x: Rauschen in x stark gestreckt.
    fibers = spectral(n, 1.1, 21, stretch=(14.0, 1.0), low=3.0)
    streaks = spectral(n, 1.8, 22, stretch=(6.0, 1.0), low=2.0)
    rings = 0.5 + 0.5 * np.sin(streaks * 28.0 + spectral(n, 1.5, 23, low=2.0) * 6.0)
    planks = 5
    row = (np.arange(n) + 0.5) / n * planks
    seam_dist = np.abs(row - np.round(row))[:, None] * np.ones((1, n))
    seams = 1.0 - smoothstep(0.0, 0.025, seam_dist)
    # Stoßfugen je Brett versetzt.
    rng = np.random.default_rng(24)
    offsets = rng.random(planks)
    col = (np.arange(n) + 0.5) / n
    plank_index = np.floor(row).astype(int) % planks
    butt = np.abs((col[None, :] - offsets[plank_index][:, None] + 0.5) % 1.0 - 0.5)
    butts = 1.0 - smoothstep(0.0, 0.006, butt)
    tint = spectral(n, 2.0, 25, low=1.0)
    plank_tone = (rng.random(planks)[plank_index] - 0.5)[:, None] * np.ones((1, n))
    # Fugen nur angedeutet: Kisten und Fässer von KayKit haben ihre Bretter schon im Modell.
    seams *= 0.25
    butts *= 0.25
    height = 0.45 * fibers + 0.25 * rings + 0.1 * tint - 0.6 * seams - 0.4 * butts
    height = (height - height.min()) / (height.max() - height.min())
    albedo = 0.5 + 0.2 * (rings - 0.5) + 0.16 * (fibers - 0.5) + 0.2 * plank_tone
    albedo += 0.12 * (tint - 0.5) - 0.35 * seams - 0.25 * butts
    roughness = 0.68 + 0.15 * (1.0 - fibers) + 0.15 * seams
    cavity = np.clip(1.0 - 0.9 * seams - 0.7 * butts, 0.0, 1.0)
    save_rgba("wood_detail.png", [albedo, roughness, cavity, height])
    Image.fromarray(normal_map(height, 6.0), "RGB").save(os.path.join(OUT, "wood_normal.png"))


def macro() -> None:
    n = 512
    dirt = spectral(n, 2.4, 31, low=1.0)
    moss = spectral(n, 2.2, 32, low=1.0) * 0.7 + spectral(n, 1.4, 33, low=6.0) * 0.3
    wet = spectral(n, 2.6, 34, low=1.0) * 0.8 + spectral(n, 1.5, 35, low=5.0) * 0.2
    save_rgba("macro_noise.png", [dirt, moss, wet])


def radial_falloff(n: int, power: float) -> np.ndarray:
    coords = (np.arange(n) + 0.5) / n * 2.0 - 1.0
    gx, gy = np.meshgrid(coords, coords)
    return np.clip(1.0 - np.sqrt(gx * gx + gy * gy), 0.0, 1.0) ** power


def decals() -> None:
    n = 512
    # Fleck: ausgefranster Rand, innen unregelmäßig dicht.
    shape = radial_falloff(n, 0.8) + (spectral(n, 1.8, 41, low=2.0) - 0.5) * 0.9
    alpha = smoothstep(0.18, 0.45, shape) * (0.55 + 0.45 * spectral(n, 1.3, 42, low=6.0))
    white = np.ones((n, n))
    save_rgba("decal_stain.png", [white, white, white, alpha])
    # Risse: Worley-Kanten, nur nahe der Mitte, mit Verästelung durch zweites Netz.
    f1, f2 = worley(n, 5, 43)
    g1, g2 = worley(n, 11, 44)
    wobble = spectral(n, 1.5, 45, low=3.0)
    main_crack = 1.0 - smoothstep(0.0, 1.0, (f2 - f1) / (0.012 + 0.018 * wobble))
    branches = 1.0 - smoothstep(0.0, 1.0, (g2 - g1) / (0.01 + 0.01 * wobble))
    branches *= smoothstep(0.5, 0.7, spectral(n, 1.4, 46, low=2.0))
    cracks = np.maximum(main_crack, branches * 0.8) * smoothstep(0.05, 0.5, radial_falloff(n, 1.0))
    save_rgba("decal_crack.png", [white, white, white, np.clip(cracks, 0.0, 1.0)])


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    stone()
    wood()
    macro()
    decals()
    print("Detail-Texturen geschrieben nach", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
