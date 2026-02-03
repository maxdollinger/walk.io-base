#!/walkio/busybox sh
set -eu

BB=/walkio/busybox
RESULT_DIR="/var/app"
RESULT_FILE="$RESULT_DIR/result"

$BB mkdir -p "$RESULT_DIR"

status="PASSED"

# --- check argv ---
if [ "${1:-}" != "arg1" ] || [ "${2:-}" != "arg2" ]; then
    echo "[walkio-test] argv check failed: '$*'"
    status="FAILED"
fi

# --- check env ---
if [ "${WALKIO_TOKEN:-}" != "ABC-123" ]; then
    echo "[walkio-test] env check failed: WALKIO_TOKEN='${WALKIO_TOKEN:-<unset>}'"
    status="FAILED"
fi

# --- write result ---
echo "[walkio-test] RESULT=$status"
echo "[walkio-test] writing result file $RESULT_FILE"
echo "$status" >"$RESULT_FILE"

exit 0
