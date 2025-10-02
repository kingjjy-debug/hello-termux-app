#!/usr/bin/env bash
set -euo pipefail
LOG="$HOME/downloads/ci_last_run/run_full.log"
if [ ! -s "$LOG" ]; then
  echo "[ERROR] run_full.log 이 없습니다. 먼저 ./ci_jobs_and_logs.sh 를 실행하세요."
  exit 1
fi

echo "===== [TAIL 300 LINES] ====="
tail -n 300 "$LOG"

echo
echo "===== [FIRST ERROR MARKER HITS] ====="
grep -nE "(ERROR|FAILURE|AAPT|Execution failed|Exception|not found|Could not|Missing|No such|What went wrong|Caused by:)" "$LOG" | head -n 30 || true

echo
echo "===== [Gradle Build section (assembleDebug)] ====="
awk '
  /Gradle Build \(assembleDebug\)/ {show=1; print; next}
  /Upload APK artifact/ {show=0}
  show==1 {print}
' "$LOG" | sed -n '1,400p'
