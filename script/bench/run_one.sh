#!/usr/bin/env bash
# 使い方: script/bench/run_one.sh <label> <file> <input_kind> <target_kind> [max_wait_sec]
#  label        例: csv_100k
#  input_kind   csv | binary
#  target_kind  sales_record | ledger_entry | binary_asset
# 環境変数:
#  BENCH_TOKEN  Bearer トークン (省略時は tmp/bench/token.txt を読む)
#  BENCH_BASE   API ベース URL  (デフォルト http://localhost:3000)
#  BENCH_OUT    結果出力ディレクトリ (デフォルト tmp/bench/results)
#
# 出力: $BENCH_OUT/result_<label>.txt と stdout に各種計測値

set -uo pipefail

LABEL="$1"
FILE="$2"
INPUT_KIND="$3"
TARGET_KIND="$4"
MAX_WAIT="${5:-1800}"

BASE="${BENCH_BASE:-http://localhost:3000}"
OUT_DIR="${BENCH_OUT:-tmp/bench/results}"
TOKEN_FILE="${BENCH_TOKEN_FILE:-tmp/bench/token.txt}"
mkdir -p "$OUT_DIR"

if [ -n "${BENCH_TOKEN:-}" ]; then
  TOKEN="$BENCH_TOKEN"
elif [ -f "$TOKEN_FILE" ]; then
  TOKEN=$(cat "$TOKEN_FILE")
else
  echo "ERROR: BENCH_TOKEN 環境変数か $TOKEN_FILE を用意してください" >&2
  exit 1
fi

WPID=$(pgrep -f 'solid-queue-worker' | head -1)
PUMA_PID=$(pgrep -f 'puma 8' | head -1)
WORKER_RSS_BEFORE_KB=$(ps -p "$WPID" -o rss= 2>/dev/null | tr -d ' ')
PUMA_RSS_BEFORE_KB=$(ps -p "$PUMA_PID" -o rss= 2>/dev/null | tr -d ' ')

FSIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE")
echo "[bench] $LABEL file=$FILE size=${FSIZE}B input=$INPUT_KIND target=$TARGET_KIND"

T0=$(python3 -c 'import time;print(time.time())')
RESP=$(curl -sS -X POST "$BASE/api/v1/file_imports" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@${FILE}" \
  -F "input_kind=${INPUT_KIND}" \
  -F "target_kind=${TARGET_KIND}")
T1=$(python3 -c 'import time;print(time.time())')

IMP_ID=$(echo "$RESP" | python3 -c 'import json,sys;d=json.loads(sys.stdin.read());print(d.get("data",{}).get("id",""))' 2>/dev/null)
echo "[bench] import_id=$IMP_ID upload_seconds=$(python3 -c "print(round($T1-$T0,3))")"

PEAK_W=${WORKER_RSS_BEFORE_KB:-0}
PEAK_P=${PUMA_RSS_BEFORE_KB:-0}
SECS=0
TIMED_OUT=0
while true; do
  CUR=$(curl -sS -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/file_imports/$IMP_ID")
  STATUS=$(echo "$CUR" | python3 -c 'import json,sys;d=json.loads(sys.stdin.read());print(d.get("data",{}).get("status",""))' 2>/dev/null)
  case "$STATUS" in
    completed|completed_with_errors|partially_failed|failed)
      break ;;
  esac
  CW=$(ps -p "$WPID" -o rss= 2>/dev/null | tr -d ' '); [ -n "$CW" ] && [ "$CW" -gt "$PEAK_W" ] && PEAK_W=$CW
  CP=$(ps -p "$PUMA_PID" -o rss= 2>/dev/null | tr -d ' '); [ -n "$CP" ] && [ "$CP" -gt "$PEAK_P" ] && PEAK_P=$CP
  if [ "$SECS" -ge "$MAX_WAIT" ]; then
    echo "[bench] TIMEOUT after ${MAX_WAIT}s, status=$STATUS — aborting (no longer waiting)" >&2
    TIMED_OUT=1; break
  fi
  sleep 1; SECS=$((SECS+1))
done

T2=$(python3 -c 'import time;print(time.time())')
WORKER_RSS_AFTER_KB=$(ps -p "$WPID" -o rss= 2>/dev/null | tr -d ' ')
PUMA_RSS_AFTER_KB=$(ps -p "$PUMA_PID" -o rss= 2>/dev/null | tr -d ' ')
FINAL=$(curl -sS -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/file_imports/$IMP_ID")

{
  echo "label=$LABEL"
  echo "file_size_bytes=$FSIZE"
  echo "import_id=$IMP_ID"
  echo "upload_seconds=$(python3 -c "print(round($T1-$T0,3))")"
  echo "process_seconds=$(python3 -c "print(round($T2-$T1,3))")"
  echo "total_seconds=$(python3 -c "print(round($T2-$T0,3))")"
  echo "worker_rss_before_kb=${WORKER_RSS_BEFORE_KB:-0}"
  echo "worker_rss_peak_kb=$PEAK_W"
  echo "worker_rss_after_kb=${WORKER_RSS_AFTER_KB:-0}"
  echo "puma_rss_before_kb=${PUMA_RSS_BEFORE_KB:-0}"
  echo "puma_rss_peak_kb=$PEAK_P"
  echo "puma_rss_after_kb=${PUMA_RSS_AFTER_KB:-0}"
  echo "final=$FINAL"
} > "$OUT_DIR/result_${LABEL}.txt"

if [ "$TIMED_OUT" = "1" ]; then
  echo "[bench] DONE (TIMEOUT) -> $OUT_DIR/result_${LABEL}.txt" >&2
  exit 2
fi
echo "[bench] DONE -> $OUT_DIR/result_${LABEL}.txt"
