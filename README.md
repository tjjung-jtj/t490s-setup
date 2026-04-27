# t490s-setup

ThinkPad T490s + Ubuntu 24.04 자동 셋업 스크립트.
trading-bot 학습/분석 노드(또는 일반 dev 노드) 용.

## 사용법

Ubuntu 24.04 첫 부팅 + Wi-Fi 연결 끝난 직후:

```bash
# curl 한 줄로 다운로드 + 실행
bash <(curl -fsSL https://raw.githubusercontent.com/tjjung-jtj/t490s-setup/main/t490s-bootstrap.sh)

# 또는 clone 후 실행
git clone https://github.com/tjjung-jtj/t490s-setup.git
cd t490s-setup
bash t490s-bootstrap.sh
```

sudo 비번 한 번 입력하면 끝까지 자동 진행.

## 자동화하는 것

- [2] 시스템 update/upgrade + 기본 패키지 (build-essential, git, vim, htop, tmux, python3-venv, openssh-server, rsync 등)
- [3] SSH 서버 enable + ufw allow ssh
- [4] Tailscale 설치 (인증 `sudo tailscale up`은 수동)
- [5] `/etc/systemd/logind.conf` lid switch ignore (24/7 운영)
- [6] TLP 설치 + 배터리 75-80% 한도 (수명 보호)
- [7] `.bashrc`에 PS1 초록색 (T490s=초록, GCP=빨강, build-server=노랑)

## 자동화 못 하는 것 — [MANUAL_STEPS.md](MANUAL_STEPS.md) 참조

bootstrap.sh 종료 시 [MANUAL_STEPS.md](MANUAL_STEPS.md)를 자동으로 다운로드해 `~/T490S_NEXT_STEPS.md`에 저장. 셋업 중 언제든 아래로 다시 볼 수 있음:

```bash
cat ~/T490S_NEXT_STEPS.md       # 터미널
gedit ~/T490S_NEXT_STEPS.md     # GUI 편집기
# 또는 브라우저로 GitHub 직접 접속
```

요약:
1. `sudo tailscale up` (브라우저 Google 로그인)
2. 한글 입력기 fcitx5-hangul (GUI Settings 패널 등록 + 재로그인)
3. GitHub SSH 키 생성 + 브라우저로 등록
4. trading-bot clone + dev 브랜치 + venv + pip install
5. 머신 역할 가드 3단 (bot.py / rl_train.py 상단 hostname assert + .gitignore)
6. 외장 SSD 마운트 (`lsblk`로 장치명 확인 필요)
7. GCP → 노트북 rsync (state.json, learning.json, models/)

각 단계 디테일 명령어/스크린샷 안내는 [MANUAL_STEPS.md](MANUAL_STEPS.md) 안에.

## 안전장치

- **호스트명이 `gcp`로 시작하면 즉시 종료** — GCP 봇 서버에서 실수로 실행 방지
- root로 실행 시 종료 (sudo는 필요한 명령에만)
- `/etc/systemd/logind.conf`, `/etc/tlp.conf` 수정 전 자동 백업 (`.bak.YYYYMMDD_HHMMSS`)
- 모든 단계 idempotent (재실행 안전)

## 검증

스크립트 종료 후:

```bash
# 새 터미널 열어서 프롬프트 초록인지 확인
echo $PS1

# 핵심 서비스 상태
sudo systemctl status ssh tlp tailscaled

# Tailscale IP (tailscale up 후)
tailscale ip -4
```

## 다음 단계

`t490s-bootstrap.sh` 끝나고 수동 7단계 끝나면 → Phase 1:

- `python3 rl_train.py` (5코인 × 50ep) — 첫 RL 학습
- XGBoost 24개 `.pkl` BLAS 풀스레드 재학습
- 백테스트 검증 → `models/*.pkl` GCP scp 업로드

## 관련 repo

- [ai-cli-setup](https://github.com/tjjung-jtj/ai-cli-setup) — ollama + llm + aider 스택 (1주차 안정 후 추가 설치)
