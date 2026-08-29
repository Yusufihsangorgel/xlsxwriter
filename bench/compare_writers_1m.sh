#!/bin/bash
set -u
DART="${DART:-dart}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CSV="$ROOT/bench/results/writers_1m.csv"
LOG="$ROOT/bench/results/writers_1m.log"
echo "engine,rows,cols,run,wall_s,rss_bytes,result_ms,result_peak,result_baseline,rc" > "$CSV"
: > "$LOG"

parse_wall() {
  perl -ne 'if (/([0-9.]+)\s+real/) { print $1; exit }' "$1"
}

run_one() {
  local engine="$1" rows="$2" cols="$3" run="$4"
  local stdoutf timef rc=0
  stdoutf=$(mktemp)
  timef=$(mktemp)
  echo "--- $engine rows=$rows run=$run ---" | tee -a "$LOG"
  case "$engine" in
    constant-memory|default)
      /usr/bin/time -l "$DART" run bench/bench.dart --engine="$engine" "$rows" "$cols" \
        >"$stdoutf" 2>"$timef" || rc=$?
      ;;
    excel)
      (cd "$ROOT/bench/competitors/excel" && \
        /usr/bin/time -l "$DART" run bin/bench.dart "$rows" "$cols") \
        >"$stdoutf" 2>"$timef" || rc=$?
      ;;
    excel_community)
      (cd "$ROOT/bench/competitors/excel_community" && \
        /usr/bin/time -l "$DART" run bin/bench.dart "$rows" "$cols") \
        >"$stdoutf" 2>"$timef" || rc=$?
      ;;
  esac
  cat "$stdoutf" >> "$LOG"
  cat "$timef" >> "$LOG"
  local wall rss rms rpeak rbase
  wall=$(parse_wall "$timef")
  rss=$(awk '/maximum resident set size/{print $1; exit}' "$timef")
  rms=$(awk '/^RESULT /{print $2; exit}' "$stdoutf")
  rpeak=$(awk '/^RESULT /{print $3; exit}' "$stdoutf")
  rbase=$(awk '/^RESULT /{print $4; exit}' "$stdoutf")
  : "${wall:=NA}"; : "${rss:=NA}"; : "${rms:=NA}"; : "${rpeak:=NA}"; : "${rbase:=NA}"
  echo "$engine,$rows,$cols,$run,$wall,$rss,$rms,$rpeak,$rbase,$rc" | tee -a "$CSV"
  rm -f "$stdoutf" "$timef"
}

echo "=== 1M xlsxwriter extra runs ==="
for run in 1 2 3 4 5; do
  for eng in constant-memory default; do
    run_one "$eng" 1000000 10 "$run"
    sleep 5
  done
done

echo "=== 1M excel_community (3 runs) ==="
for run in 1 2 3; do
  run_one excel_community 1000000 10 "$run"
  sleep 5
done

echo "=== 1M excel probe (one run, 6 min cap) ==="
stdoutf=$(mktemp)
timef=$(mktemp)
echo "--- excel rows=1000000 run=1 ---" | tee -a "$LOG"
rc=0
perl -e 'alarm 360; exec @ARGV' /bin/bash -c \
  "cd \"$ROOT/bench/competitors/excel\" && /usr/bin/time -l \"$DART\" run bin/bench.dart 1000000 10" \
  >"$stdoutf" 2>"$timef" || rc=$?
cat "$stdoutf" >> "$LOG"
cat "$timef" >> "$LOG"
wall=$(parse_wall "$timef")
rss=$(awk '/maximum resident set size/{print $1; exit}' "$timef")
rms=$(awk '/^RESULT /{print $2; exit}' "$stdoutf")
rpeak=$(awk '/^RESULT /{print $3; exit}' "$stdoutf")
rbase=$(awk '/^RESULT /{print $4; exit}' "$stdoutf")
: "${wall:=NA}"; : "${rss:=NA}"; : "${rms:=NA}"; : "${rpeak:=NA}"; : "${rbase:=NA}"
echo "excel,1000000,10,1,$wall,$rss,$rms,$rpeak,$rbase,$rc" | tee -a "$CSV"
rm -f "$stdoutf" "$timef"

echo "=== DONE ==="
cat "$CSV"
