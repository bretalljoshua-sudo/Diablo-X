#!/usr/bin/env bash
# Führt alle GUT-Tests headless aus und startet danach jede Testszene aus debug/
# kurz ohne Bildschirm (Rauchtest). Schlägt fehl bei fehlgeschlagenen Tests und bei
# Skriptfehlern im Log, denn Godot selbst beendet sich trotz Parse-Fehlern mit 0.
#
# Aufruf: tools/run_tests.sh            alles
#         tools/run_tests.sh --no-smoke nur GUT-Tests
# Godot wird bei Bedarf über tools/install_godot.sh geladen; eigener Pfad über $GODOT.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

GODOT="${GODOT:-$(tools/install_godot.sh)}"
LOG_DIR="${TEST_LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"
ERROR_PATTERN='SCRIPT ERROR|Parse Error|^ERROR:|Failed to load script'
failed=0

check_log() {
	local name="$1" log="$2"
	if [[ ! -s "$log" ]]; then
		echo "::error::Kein Log für $name ($log)."
		failed=1
	elif grep -qE "$ERROR_PATTERN" "$log"; then
		echo "::error::Fehler im Log von $name:"
		grep -E -A3 "$ERROR_PATTERN" "$log" | head -40
		failed=1
	fi
}

echo "== Import =="
"$GODOT" --headless --path . --import >"$LOG_DIR/import.log" 2>&1
check_log "Import" "$LOG_DIR/import.log"

echo "== GUT-Tests =="
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json \
	2>&1 | tee "$LOG_DIR/gut.log"
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
	echo "::error::GUT-Tests fehlgeschlagen."
	failed=1
fi
check_log "GUT" "$LOG_DIR/gut.log"

if [[ "${1:-}" != "--no-smoke" ]]; then
	scenes="$("$GODOT" --headless --path . -- --list-scenes 2>/dev/null \
		| sed -n 's/^Testszenen: //p' | tr -d ',')"
	for scene in $scenes; do
		echo "== Rauchtest: $scene =="
		"$GODOT" --headless --path . --quit-after 180 -- --scene="$scene" \
			>"$LOG_DIR/smoke_$scene.log" 2>&1
		check_log "Rauchtest $scene" "$LOG_DIR/smoke_$scene.log"
	done
fi

if [[ $failed -ne 0 ]]; then
	echo "FEHLGESCHLAGEN (Logs in $LOG_DIR)"
	exit 1
fi
echo "Alles grün."
