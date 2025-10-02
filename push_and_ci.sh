#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG ======
REPO_OWNER="kingjjy-debug"
REPO_NAME="hello-termux-app"
REPO="$REPO_OWNER/$REPO_NAME"
BRANCH="main"
WORKFLOW_FILE="android-ci.yml"
DOWNLOAD_DIR="$HOME/downloads"
COMMIT_MSG="${1:-Update}"

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "[ERROR] '$1' 명령이 필요합니다."; exit 1; }; }
require_cmd gh
require_cmd git

if ! gh auth status >/dev/null 2>&1; then
  echo "[ERROR] gh 로그인이 필요합니다: gh auth login"
  exit 1
fi

cd "$HOME/apk_prj_ver_1"

# 미리 기존 최신 RUN_ID 스냅샷(참고용)
PREV_RUN_ID="$(gh run list --repo "$REPO" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || echo "")"

# GIT 준비 및 PUSH
if [ ! -d .git ]; then
  git init
  git config user.name "${GIT_USER_NAME:-$(gh api user -q .login || echo 'user')}"
  git config user.email "${GIT_USER_EMAIL:-you@example.com}"
  git add .
  git commit -m "$COMMIT_MSG"
  git branch -M "$BRANCH"
else
  git add .
  git commit -m "$COMMIT_MSG" || true
fi

if ! gh repo view "$REPO" >/dev/null 2>&1; then
  echo "[INFO] GitHub repo가 없어 새로 만듭니다: $REPO"
  gh repo create "$REPO" --public -y
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "https://github.com/$REPO.git"
fi

git push -u origin "$BRANCH"

# 내 커밋 SHA
HEAD_SHA="$(git rev-parse HEAD)"

# ====== 새 Run (push 트리거) 기다리기: HEAD_SHA 매칭되는 것만 선택 ======
echo "[INFO] 새 런이 생성될 때까지 대기 (내 커밋 SHA 매칭)"
NEW_RUN_ID=""
for i in $(seq 1 30); do
  while IFS=$'\t' read -r rid sha status; do
    if [ "$sha" = "$HEAD_SHA" ]; then
      NEW_RUN_ID="$rid"
      break
    fi
  done < <(gh run list --repo "$REPO" --limit 10 --json databaseId,headSha,status -q '.[] | "\(.databaseId)\t\(.headSha)\t\(.status)"' 2>/dev/null || echo "")
  if [ -n "$NEW_RUN_ID" ] && [ "$NEW_RUN_ID" != "$PREV_RUN_ID" ]; then
    break
  fi
  sleep 3
done

if [ -z "$NEW_RUN_ID" ]; then
  echo "[ERROR] 새 워크플로우 런을 찾지 못했습니다."
  gh run list --repo "$REPO" --limit 10 || true
  exit 1
fi

echo "[INFO] 추적할 RUN_ID: $NEW_RUN_ID"

# ====== WATCH STATUS ======
echo "[INFO] 실행 로그/상태를 추적합니다..."
if gh run watch --repo "$REPO" "$NEW_RUN_ID" --interval 5 --exit-status; then
  echo "[INFO] ✅ 빌드 성공"
else
  echo "[ERROR] ❌ 빌드 실패"
  echo "------ 최근 로그 ------"
  gh run view --repo "$REPO" "$NEW_RUN_ID" --log || true
  exit 1
fi

# ====== DOWNLOAD ARTIFACTS ======
mkdir -p "$DOWNLOAD_DIR"
echo "[INFO] 아티팩트 다운로드 → $DOWNLOAD_DIR"
if ! gh run download --repo "$REPO" "$NEW_RUN_ID" --name "app-debug-apk" -D "$DOWNLOAD_DIR"; then
  echo "[WARN] 지정 이름으로 다운로드 실패. 전체 아티팩트 시도."
  gh run download --repo "$REPO" "$NEW_RUN_ID" -D "$DOWNLOAD_DIR" || true
fi

echo "[INFO] 다운로드 완료. 폴더 목록:"
ls -lh "$DOWNLOAD_DIR" || true
echo "[INFO] (APK는 보통 app-debug-apk/*.apk 로 제공됩니다)"
