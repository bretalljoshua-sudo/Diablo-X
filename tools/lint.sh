#!/usr/bin/env bash
# Prüft Formatierung (gdformat) und Stil (gdlint) aller eigenen GDScript-Dateien.
# Voraussetzung: pip install "gdtoolkit==4.5.0"
# Mit --fix wird die Formatierung direkt korrigiert.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

mapfile -t FILES < <(git ls-files --cached --others --exclude-standard '*.gd' | grep -v '^addons/')
if [[ ${#FILES[@]} -eq 0 ]]; then
	echo "Keine GDScript-Dateien gefunden."
	exit 0
fi

if [[ "${1:-}" == "--fix" ]]; then
	gdformat "${FILES[@]}"
else
	gdformat --check "${FILES[@]}"
fi
gdlint "${FILES[@]}"
