#!/usr/bin/env bash
# Exportiert den Windows-Build nach build/windows/ (SpielJBR.exe + SpielJBR.console.exe).
# Lädt Godot und die Exportvorlagen bei Bedarf über tools/install_godot.sh.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

GODOT="${GODOT:-$(tools/install_godot.sh --templates)}"
tools/install_godot.sh --templates >/dev/null
mkdir -p build/windows
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/SpielJBR.exe \
	2>&1 | tee build/export.log
if [[ ! -s build/windows/SpielJBR.exe ]]; then
	echo "::error::Export fehlgeschlagen, keine SpielJBR.exe erzeugt."
	exit 1
fi
if grep -qE 'SCRIPT ERROR|Parse Error|^ERROR:' build/export.log; then
	echo "::error::Fehler beim Export, siehe build/export.log."
	exit 1
fi
ls -la build/windows
