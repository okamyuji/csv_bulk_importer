#!/usr/bin/env bash
# 一括ベンチランナー。指定された case か "all" を順に実行する。
# 使い方: script/bench/run.sh [case ...]
#   case: csv_100k | csv_1m | img_small | img_large | all
# 環境変数:
#   BENCH_BASE   API ベース URL  (デフォルト http://localhost:3000)
#   BENCH_OUT    結果出力ディレクトリ (デフォルト tmp/bench/results)
#   BENCH_TOKEN  Bearer トークン直指定 (省略時は tmp/bench/token.txt)
#   BENCH_USER_EMAIL / BENCH_USER_PASSWORD ユーザー作成/ログイン用 (省略時は bench@example.com / Password1!)

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
BENCH_DIR="$ROOT_DIR/script/bench"
DATA_DIR="${BENCH_DATA:-tmp/bench}"
OUT_DIR="${BENCH_OUT:-tmp/bench/results}"
mkdir -p "$DATA_DIR" "$OUT_DIR"

BASE="${BENCH_BASE:-http://localhost:3000}"
EMAIL="${BENCH_USER_EMAIL:-bench@example.com}"
PASS="${BENCH_USER_PASSWORD:-Password1!}"

# --- token: register or sign in ---
acquire_token() {
  local resp token
  resp=$(curl -sS -i -X POST "$BASE/api/v1/registrations" \
    -H 'Content-Type: application/json' \
    -d "{\"user\":{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"password_confirmation\":\"$PASS\",\"name\":\"bench\"}}")
  token=$(echo "$resp" | grep -i '^Authorization:' | awk '{print $3}' | tr -d '\r\n')
  if [ -z "$token" ]; then
    resp=$(curl -sS -i -X POST "$BASE/api/v1/sessions" \
      -H 'Content-Type: application/json' \
      -d "{\"user\":{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}}")
    token=$(echo "$resp" | grep -i '^Authorization:' | awk '{print $3}' | tr -d '\r\n')
  fi
  if [ -z "$token" ]; then
    echo "ERROR: ログインも登録も失敗しました" >&2
    return 1
  fi
  printf '%s' "$token" > "$DATA_DIR/token.txt"
  echo "[run] token written -> $DATA_DIR/token.txt"
}

ensure_token() {
  if [ -n "${BENCH_TOKEN:-}" ]; then
    printf '%s' "$BENCH_TOKEN" > "$DATA_DIR/token.txt"
    return
  fi
  if [ ! -s "$DATA_DIR/token.txt" ]; then
    acquire_token
  fi
}

ensure_csv_100k() {
  [ -f "$DATA_DIR/sales_100k.csv" ] || ruby "$BENCH_DIR/gen_csv.rb" 100000   "$DATA_DIR/sales_100k.csv"
}
ensure_csv_1m() {
  [ -f "$DATA_DIR/sales_1m.csv" ]   || ruby "$BENCH_DIR/gen_csv.rb" 1000000  "$DATA_DIR/sales_1m.csv"
}
ensure_img_small() {
  [ -f "$DATA_DIR/img_small.jpg" ]  || ruby "$BENCH_DIR/gen_image.rb" 5   "$DATA_DIR/img_small.jpg"
}
ensure_img_large() {
  [ -f "$DATA_DIR/img_large.jpg" ]  || ruby "$BENCH_DIR/gen_image.rb" 300 "$DATA_DIR/img_large.jpg"
}

run_case() {
  local label="$1"
  case "$label" in
    csv_100k)  ensure_csv_100k;  BENCH_OUT="$OUT_DIR" BENCH_TOKEN_FILE="$DATA_DIR/token.txt" "$BENCH_DIR/run_one.sh" csv_100k  "$DATA_DIR/sales_100k.csv" csv    sales_record  90 ;;
    csv_1m)    ensure_csv_1m;    BENCH_OUT="$OUT_DIR" BENCH_TOKEN_FILE="$DATA_DIR/token.txt" "$BENCH_DIR/run_one.sh" csv_1m    "$DATA_DIR/sales_1m.csv"   csv    sales_record  240 ;;
    img_small) ensure_img_small; BENCH_OUT="$OUT_DIR" BENCH_TOKEN_FILE="$DATA_DIR/token.txt" "$BENCH_DIR/run_one.sh" img_small "$DATA_DIR/img_small.jpg"  binary binary_asset   30 ;;
    img_large) ensure_img_large; BENCH_OUT="$OUT_DIR" BENCH_TOKEN_FILE="$DATA_DIR/token.txt" "$BENCH_DIR/run_one.sh" img_large "$DATA_DIR/img_large.jpg"  binary binary_asset  120 ;;
    *) echo "unknown case: $label (csv_100k|csv_1m|img_small|img_large|all)" >&2; return 1 ;;
  esac
}

ensure_token

if [ $# -eq 0 ] || [ "$1" = "all" ]; then
  cases=(csv_100k csv_1m img_small img_large)
else
  cases=("$@")
fi

for c in "${cases[@]}"; do run_case "$c"; done

echo "[run] summarizing..."
bin/rails runner script/bench/summarize.rb
