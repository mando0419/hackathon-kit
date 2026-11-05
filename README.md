# hackathon-kit

AI 코딩 에이전트(Codex)로 3시간 업무형 웹 과제를 진행할 때 쓰는 **작업 규칙, 진행 절차(Skill), 템플릿, 제출 점검 스크립트** 모음입니다.
특정 과제의 답이나 구현 코드는 들어 있지 않습니다.

## 구성
- `AGENTS.md` : 에이전트 작업 규칙 (작업 폴더에 복사해서 포트 등만 수정)
- `skills/hackathon-workflow/SKILL.md` : 시간대별 진행 절차
- `prompts.md` : 단계별 프롬프트 모음
- `templates/` : PLAN, NOTES, REQ_CHECK, ARCHITECTURE, HANDOFF, AI_COLLABORATION 작성 가이드
- `checklists/SUBMIT_CHECKLIST.md` : 마지막 30분 체크리스트
- `scripts/preflight.sh` : 제출 전 자동 점검 (제공 문서 수정 여부, 필수 문서, .env.example 값, git 상태, 개인 파일, Docker 빌드)

## 사용법
```
git clone https://github.com/mando0419/hackathon-kit /tmp/kit
bash /tmp/kit/scripts/preflight.sh            # 작업 폴더에서 실행
bash /tmp/kit/scripts/preflight.sh --docker   # Docker 빌드까지 확인
```
프로젝트 폴더 밖(/tmp 등)에 받아서 필요한 파일만 복사합니다.
