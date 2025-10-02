#!/usr/bin/env bash
set -euo pipefail

REPO="kingjjy-debug/hello-termux-app"
OUT_DIR="$HOME/downloads"
mkdir -p "$OUT_DIR"

LAST_ID="$(gh run list --repo "$REPO" --limit 1 --json databaseId -q '.[0].databaseId')"
echo "[INFO] LAST RUN_ID: $LAST_ID"

# 전체 로그 저장
gh run view --repo "$REPO" "$LAST_ID" --log > "$OUT_DIR/ci_full_log.txt" || {
  echo "[WARN] run log not found. 출력 가능한 메타만 저장합니다."
}

# 메타 정보 저장
gh run view --repo "$REPO" "$LAST_ID" --json name,headSha,conclusion,status,startedAt,updatedAt,headBranch,event,actor,jobs > "$OUT_DIR/ci_meta.json" || true

# 아티팩트(있으면) 받아두기
mkdir -p "$OUT_DIR/last_run"
gh run download --repo "$REPO" "$LAST_ID" -D "$OUT_DIR/last_run" || true

echo "[INFO] 저장 완료:"
ls -lh "$OUT_DIR" || true
echo "[INFO] 로그 파일 경로: $OUT_DIR/ci_full_log.txt"
