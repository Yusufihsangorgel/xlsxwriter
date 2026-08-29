#!/bin/bash
set -u
DART="${DART:-dart}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CSV="$ROOT/bench/results/writers.csv"
LOG="$ROOT/bench/results/writers.log"
echo "engine,rows,cols,run,wall_s,rss_bytes,result_ms,result_peak,result_baseline,rc" > "$CSV"
: > "$LOG"

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
    *)
      echo "unknown engine $engine"
      return 1
      ;;
  esac
  cat "$stdoutf" >> "$LOG"
  cat "$timef" >> "$LOG"
  local wall rss rms rpeak rbase
  wall=$(awk '/ real /{print $1; exit}' "$timef")
  rss=$(awk '/maximum resident set size/{print $1; exit}' "$timef")
  rms=$(awk '/^RESULT /{print $2; exit}' "$stdoutf")
  rpeak=$(awk '/^RESULT /{print $3; exit}' "$stdoutf")
  rbase=$(awk '/^RESULT /{print $4; exit}' "$stdoutf")
  : "${wall:=NA}"; : "${rss:=NA}"; : "${rms:=NA}"; : "${rpeak:=NA}"; : "${rbase:=NA}"
  echo "$engine,$rows,$cols,$run,$wall,$rss,$rms,$rpeak,$rbase,$rc" | tee -a "$CSV"
  rm -f "$stdoutf" "$timef"
  return 0
}

echo "=== extra cache warmup at 1000 rows ==="
for eng in constant-memory default excel excel_community; do
  run_one "$eng" 1000 10 0
done

for rows in 10000 100000; do
  echo "======== SIZE $rows ========"
  for run in 1 2 3 4 5; do
    for eng in constant-memory default excel excel_community; do
      run_one "$eng" "$rows" 10 "$run"
      sleep 2
    done
  done
done

echo "======== SIZE 1000000 (xlsxwriter) ========"
for run in 1 2 3; do
  for eng in constant-memory default; do
    run_one "$eng" 1000000 10 "$run"
    sleep 2
  done
done

echo "=== DONE (xlsxwriter 1M + all smaller sizes) ==="
cat "$CSV"
