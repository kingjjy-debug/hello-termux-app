#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG ======
REPO_OWNER="kingjjy-debug"
REPO_NAME="hello-termux-app"
REPO="$REPO_OWNER/$REPO_NAME"
BRANCH="main"
WORKFLOW_FILE="android-ci.yml"
DOWNLOAD_DIR="$HOME/downloads"
COMMIT_MSG="${1:-Initial commit: HelloTermuxApp}"

# ====== CHECKS ======
if ! command -v gh >/dev/null 2>&1; then
  echo "[ERROR] GitHub CLI(gh)가 필요합니다. 다음으로 설치하세요:"
  echo "pkg update && pkg install gh -y"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[ERROR] gh 로그인이 필요합니다. 다음을 실행해 로그인하세요:"
  echo "gh auth login"
  exit 1
fi

# ====== GIT INIT & FIRST PUSH ======
cd "$HOME/apk_prj_ver_1"

if [ ! -d .git ]; then
  git init
  git config user.name "${GIT_USER_NAME:-$(gh api user -q .login || echo 'user')}"
  # 이메일이 비공개일 수 있으므로 fallback 지정
  git config user.email "${GIT_USER_EMAIL:-you@example.com}"
  git add .
  git commit -m "$COMMIT_MSG"
  git branch -M "$BRANCH"
else
  # 기존 git 프로젝트면 변경분만 커밋
  git add .
  git commit -m "$COMMIT_MSG" || true
fi

# 리포 존재 여부 확인 후 생성
if ! gh repo view "$REPO" >/dev/null 2>&1; then
  echo "[INFO] GitHub repo가 없어 새로 만듭니다: $REPO"
  gh repo create "$REPO" --public -y
fi

# 리모트 설정(https 사용: SSH 키 불필요)
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "https://github.com/$REPO.git"
fi

# 푸시
git push -u origin "$BRANCH"

# ====== TRIGGER WORKFLOW ======
# 워크플로우 파일이 기본 브랜치에 있어야 함
echo "[INFO] 워크플로우 트리거: $WORKFLOW_FILE"
if ! gh workflow run "$WORKFLOW_FILE" --repo "$REPO" >/dev/null 2>&1; then
  echo "[WARN] 'workflow_dispatch'가 비활성화된 경우가 있어, 최신 커밋으로 자동 실행된 런을 추적합니다."
fi

# 최신 런 ID 추출 (조금 대기 후 재시도)
attempt=0
RUN_ID=""
while [ $attempt -lt 10 ]; do
  RUN_ID=$(gh run list --repo "$REPO" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || echo "")
  if [ -n "$RUN_ID" ]; then
    break
  fi
  attempt=$((attempt+1))
  sleep 3
done

if [ -z "$RUN_ID" ]; then
  echo "[ERROR] 최신 워크플로우 런을 찾지 못했습니다."
  gh run list --repo "$REPO" || true
  exit 1
fi

echo "[INFO] 추적할 RUN_ID: $RUN_ID"

# ====== WATCH STATUS ======
echo "[INFO] 실행 로그/상태를 추적합니다..."
if gh run watch --repo "$REPO" "$RUN_ID" --interval 5 --exit-status; then
  echo "[INFO] ✅ 빌드 성공"
else
  echo "[ERROR] ❌ 빌드 실패"
  echo "------ 최근 로그 ------"
  gh run view --repo "$REPO" "$RUN_ID" --log || true
  exit 1
fi

# ====== DOWNLOAD ARTIFACTS ======
mkdir -p "$DOWNLOAD_DIR"
echo "[INFO] 아티팩트를 다운로드합니다 → $DOWNLOAD_DIR"
if ! gh run download --repo "$REPO" "$RUN_ID" -D "$DOWNLOAD_DIR"; then
  echo "[WARN] 아티팩트 다운로드 실패 또는 없음."
  exit 0
fi

echo "[INFO] 다운로드 완료. 폴더 목록:"
ls -lh "$DOWNLOAD_DIR"
echo "[INFO] (APK는 보통 app-debug-apk/*.apk 로 제공됩니다)"
