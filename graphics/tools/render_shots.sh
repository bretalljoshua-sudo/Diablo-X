#!/usr/bin/env bash
# Rendert Screenshots von Testszenen ohne Grafikkarte (Software-Rendering), für Vorher/Nachher-
# Vergleiche in der Cloud. Forward+ läuft über Vulkan mit Lavapipe (Paket mesa-vulkan-drivers),
# sonst fällt das Skript auf den Compatibility-Renderer zurück (ohne SDFGI, Volumennebel, SSR).
#
# Aufruf: graphics/tools/render_shots.sh <ausgabeordner> <name> <szene> [weitere Spielargumente …]
# Beispiel: graphics/tools/render_shots.sh /tmp/shots dungeon world_test --depth=1 --seed=7
# Umgebungsvariablen: FRAMES (Standard 90), RESOLUTION (Standard 1920x1080), RENDERER (forward_plus
# oder gl_compatibility), ANISO (Standard 0: anisotrope Filterung aus, Software-Rendering ist damit
# etwa doppelt so schnell; 1 = wie im Spiel).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

OUT="$1"
NAME="$2"
SCENE="$3"
shift 3
GODOT="${GODOT:-$(tools/install_godot.sh)}"
FRAMES="${FRAMES:-90}"
RENDERER="${RENDERER:-forward_plus}"
LVP=/usr/share/vulkan/icd.d/lvp_icd.json
mkdir -p "$OUT"

# Nur für diesen Lauf: override.cfg im Projekt, danach wieder weg.
if [[ "${ANISO:-0}" == "0" && ! -e override.cfg ]]; then
	printf '[rendering]\n\ntextures/default_filters/anisotropic_filtering_level=0\n' >override.cfg
	trap 'rm -f override.cfg' EXIT
fi

if [[ "$RENDERER" == "forward_plus" && -f "$LVP" ]]; then
	DRIVER=(--rendering-driver vulkan --rendering-method forward_plus)
	export VK_ICD_FILENAMES="$LVP"
else
	DRIVER=(--rendering-driver opengl3 --rendering-method gl_compatibility)
fi

xvfb-run -a -s "-screen 0 ${RESOLUTION:-1920x1080}x24" "$GODOT" --path . --fixed-fps 30 "${DRIVER[@]}" \
	-- --scene="$SCENE" --screenshot="$OUT/$NAME.png" --screenshot-frames="$FRAMES" "$@" \
	>"$OUT/$NAME.log" 2>&1
grep -E "^Screenshot:|SCRIPT ERROR" "$OUT/$NAME.log"
