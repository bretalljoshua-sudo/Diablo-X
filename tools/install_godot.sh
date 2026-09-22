#!/usr/bin/env bash
# Lädt Godot (Linux, headless nutzbar) in der Version aus .godot-version herunter.
# Mit --templates werden zusätzlich die Windows-Exportvorlagen installiert.
#
# Aufruf:  tools/install_godot.sh [--templates]
# Danach:  export GODOT="$(tools/install_godot.sh --print-path)"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/.godot-version")"
CACHE="${GODOT_CACHE:-$HOME/.cache/godot}"
BIN_DIR="$CACHE/$VERSION"
BIN="$BIN_DIR/Godot_v${VERSION}-stable_linux.x86_64"
BASE_URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${VERSION}.stable"

if [[ "${1:-}" == "--print-path" ]]; then
	echo "$BIN"
	exit 0
fi

if [[ ! -x "$BIN" ]]; then
	echo "Lade Godot $VERSION …" >&2
	mkdir -p "$BIN_DIR"
	curl -sSL --fail -o "$BIN_DIR/godot.zip" "$BASE_URL/Godot_v${VERSION}-stable_linux.x86_64.zip"
	unzip -q -o "$BIN_DIR/godot.zip" -d "$BIN_DIR"
	rm "$BIN_DIR/godot.zip"
	chmod +x "$BIN"
fi

if [[ "${1:-}" == "--templates" && ! -f "$TEMPLATE_DIR/windows_release_x86_64.exe" ]]; then
	echo "Lade Exportvorlagen für $VERSION (rund 1,3 GB) …" >&2
	mkdir -p "$TEMPLATE_DIR"
	TPZ="$(mktemp -d)/templates.tpz"
	curl -sSL --fail -o "$TPZ" "$BASE_URL/Godot_v${VERSION}-stable_export_templates.tpz"
	# Nur die Windows-x86_64-Vorlagen auspacken, der Rest wird nicht gebraucht.
	unzip -q -o -j "$TPZ" \
		templates/version.txt \
		templates/windows_release_x86_64.exe \
		templates/windows_release_x86_64_console.exe \
		templates/windows_debug_x86_64.exe \
		templates/windows_debug_x86_64_console.exe \
		-d "$TEMPLATE_DIR"
	rm -rf "$(dirname "$TPZ")"
fi

echo "$BIN"
