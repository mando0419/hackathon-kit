#!/usr/bin/env bash
# 제출 전 자동 점검. 작업 폴더(git 저장소 루트)에서 실행한다.
#   bash preflight.sh            기본 점검
#   bash preflight.sh --docker   Docker 빌드까지 확인
#   bash preflight.sh --url http://localhost:3000/health   헬스체크 응답 확인
# 아무것도 고치지 않는다. 결과만 보여 준다.

DOCKER=0; URL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --docker) DOCKER=1 ;;
    --url) shift; URL="$1" ;;
  esac
  shift
done

pass=0; warn=0; fail=0
ok()   { echo "  [PASS] $1"; pass=$((pass+1)); }
wa()   { echo "  [WARN] $1"; warn=$((warn+1)); }
no()   { echo "  [FAIL] $1"; fail=$((fail+1)); }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git 저장소가 아니에요. 작업 폴더 루트에서 실행하세요."; exit 1
fi
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" || exit 1
echo "점검 위치: $ROOT"

echo "1) 제공 문서 보존"
for f in README.md TASK.md; do
  [ -f "$f" ] || continue
  first=$(git log --diff-filter=A --format=%H -- "$f" 2>/dev/null | tail -1)
  if [ -z "$first" ]; then wa "$f 가 아직 커밋되지 않아 원본과 비교할 수 없음"; continue; fi
  if git diff --quiet "$first" -- "$f"; then ok "$f 가 처음 커밋된 상태 그대로"; else no "$f 가 처음 커밋 이후 바뀜 (제공 지시문은 수정 금지)"; fi
done

echo "2) 필수 문서"
for f in HOW_TO_RUN.md AI_COLLABORATION.md; do
  [ -f "$f" ] && ok "$f 있음" || no "$f 없음"
done
ls AGENTS.md CLAUDE.md >/dev/null 2>&1 && ok "프로젝트 컨텍스트 파일(AGENTS.md/CLAUDE.md) 있음" || no "AGENTS.md 또는 CLAUDE.md 없음"
if [ -f HOW_TO_RUN.md ]; then
  n=$(grep -cE '^## [1-7]\.' HOW_TO_RUN.md)
  [ "$n" -ge 7 ] && ok "HOW_TO_RUN.md 항목 7개" || wa "HOW_TO_RUN.md 항목이 ${n}개 (양식은 7개)"
  grep -qE '^\((무엇을|사용한|필요한|실행|기본|테스트 실행|판단에)' HOW_TO_RUN.md && wa "HOW_TO_RUN.md 에 양식 안내 문구(괄호)가 남아 있음"
fi
if [ -f AI_COLLABORATION.md ]; then
  c=$(grep -c '^(답변)' AI_COLLABORATION.md)
  [ "$c" -eq 0 ] && ok "AI_COLLABORATION.md 답변 작성됨" || no "AI_COLLABORATION.md 에 빈 답변 ${c}개"
fi

echo "3) 배포 준비"
if [ -f .env.example ]; then
  bad=$(grep -E '^[A-Za-z_]*(PASS|PASSWORD|SECRET|TOKEN|KEY)[A-Za-z_]*=.+' .env.example | grep -vE '=(change-me|changeme|your-|<|\$\{)' )
  [ -z "$bad" ] && ok ".env.example 에 비밀 값 없음" || wa ".env.example 에 실제처럼 보이는 비밀 값: $(echo "$bad" | cut -d= -f1 | tr '\n' ' ')"
else
  no ".env.example 없음"
fi
[ -f Dockerfile ] && ok "Dockerfile 있음" || no "Dockerfile 없음"
if [ -f Dockerfile ]; then
  git ls-files --error-unmatch Dockerfile >/dev/null 2>&1 && ok "Dockerfile 커밋됨" || no "Dockerfile 이 커밋되지 않음"
fi
lh=$(grep -rIl --exclude-dir=node_modules --exclude-dir=.git -E "listen\([^)]*(localhost|127\.0\.0\.1)" . 2>/dev/null | head -3 | tr '\n' ' ')
[ -z "$lh" ] && ok "localhost 전용 바인딩 없음" || wa "localhost 바인딩 의심 (0.0.0.0 필요): $lh"

echo "4) git 상태"
untracked=$(git ls-files --others --exclude-standard)
modified=$(git diff --name-only; git diff --cached --name-only)
[ -z "$untracked" ] && ok "Untracked 파일 없음" || wa "Untracked 파일: $(echo "$untracked" | head -8 | tr '\n' ' ')"
[ -z "$modified" ] && ok "커밋 안 된 수정 없음" || wa "커밋 안 된 수정: $(echo "$modified" | sort -u | head -8 | tr '\n' ' ')"
for p in .bash_history .bashrc .profile .sudo_as_admin_successful .env .env.local; do
  if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then no "$p 가 커밋되어 있음"; fi
  if echo "$untracked" | grep -qx "$p"; then wa "$p 가 .gitignore 에 없음"; fi
done
git ls-files | grep -q '^node_modules/' && no "node_modules 가 커밋되어 있음"
cnt=$(git rev-list --count HEAD 2>/dev/null || echo 0)
[ "$cnt" -ge 4 ] && ok "커밋 ${cnt}개" || wa "커밋 ${cnt}개 (마일스톤 단위로 더 쌓는 것을 권장)"

if [ -n "$URL" ]; then
  echo "5) 헬스체크"
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL")
  [ "$code" = "200" ] && ok "$URL → 200" || no "$URL → $code"
fi

if [ "$DOCKER" = 1 ]; then
  echo "6) Docker 빌드"
  if command -v docker >/dev/null 2>&1 && [ -f Dockerfile ]; then
    if docker build -q -t preflight-check . >/dev/null 2>&1; then ok "docker build 성공"; else no "docker build 실패 (docker build . 로 직접 확인)"; fi
  else
    wa "docker 명령 또는 Dockerfile 없음"
  fi
fi

echo
echo "결과: PASS $pass / WARN $warn / FAIL $fail"
[ "$fail" -eq 0 ]
