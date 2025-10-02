#!/usr/bin/env bash
set -euo pipefail

REPO="kingjjy-debug/hello-termux-app"
OUT_DIR="$HOME/downloads/ci_last_run"
mkdir -p "$OUT_DIR"

RUN_ID="$(gh run list --repo "$REPO" --limit 1 --json databaseId -q '.[0].databaseId')"
if [ -z "${RUN_ID:-}" ]; then
  echo "[ERROR] 최근 Run을 찾지 못했습니다."
  gh run list --repo "$REPO" --limit 5 || true
  exit 1
fi
echo "[INFO] RUN_ID: $RUN_ID"

echo "[INFO] Saving run meta..."
# 'actor' 제거, 호환 필드만 사용
gh run view --repo "$REPO" "$RUN_ID" \
  --json name,headSha,conclusion,status,startedAt,updatedAt,headBranch,event,jobs,workflowName,number,url \
  > "$OUT_DIR/run_meta.json" || true

echo "[INFO] Saving whole run log (combined)..."
# 잡 단위 로그가 안 쌓일 때 대비하여 전체 로그도 따로 저장
gh run view --repo "$REPO" "$RUN_ID" --log > "$OUT_DIR/run_full.log" || echo "[WARN] run_full.log not available"

echo "[INFO] Listing jobs..."
if ! gh run view --repo "$REPO" "$RUN_ID" --json jobs -q '.jobs[] | "\(.databaseId)\t\(.name)\t\(.status)\t\(.conclusion)"' \
  | tee "$OUT_DIR/jobs.tsv"; then
  echo "[WARN] jobs TSV 생성 실패. 잡 단위 로그가 없을 수 있습니다."
  : > "$OUT_DIR/jobs.tsv"
fi

# 개별 잡 로그 저장 (가능한 경우에만)
if [ -s "$OUT_DIR/jobs.tsv" ]; then
  while IFS=$'\t' read -r JID JNAME JSTATUS JCONC; do
    [ -z "${JID:-}" ] && continue
    SAFE="$(echo "$JNAME" | tr ' /' '__' | tr -cd '[:alnum:]_-.')"
    echo "[INFO] Fetching log for job: $JID ($JNAME)"
    gh run view --repo "$REPO" --job "$JID" --log > "$OUT_DIR/job_${JID}_${SAFE}.log" || echo "[WARN] no log for job $JID"
  done < "$OUT_DIR/jobs.tsv"
else
  echo "[INFO] jobs.tsv 가 비어있어 잡 로그 수집을 생략합니다."
fi

echo "[INFO] Files saved under: $OUT_DIR"
ls -lh "$OUT_DIR" || true

echo "[INFO] Grepping for common error markers..."
grep -nE "(ERROR|FAILURE|AAPT|Execution failed|Exception|not found|Could not|Missing|No such|What went wrong|Caused by:)" "$OUT_DIR"/*.log 2>/dev/null || true
