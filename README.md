# t490s-setup

ThinkPad T490s + Ubuntu 24.04 자동 셋업 스크립트.
trading-bot 학습/분석 노드 용.

## 전체 워크플로우 (60~90분, 그중 사용자 직접 6~7분)

```
1. BIOS + Ubuntu 설치 (USB 부팅)              ← 사용자 30~60분
2. bootstrap.sh                                ← 자동 5~10분
3. sudo tailscale up (브라우저 Google 로그인)   ← 사용자 1분
4. finalize.sh                                  ← 자동 20~30분
   ├ 한글 입력기 + talib
   ├ ssh-keygen + GitHub 등록 (사용자 2분)
   ├ trading-bot clone + venv + 머신 가드
   ├ AI CLI 스택 (ai-cli-setup repo 호출)
   ├ build-server에서 llm 키 자동 복사
   └ 외장 SSD 자동 마운트 (선택)
5. fcitx5 GUI 등록 + 재로그인                   ← 사용자 2분
6. GCP authorized_keys에 노트북 키 추가         ← 사용자 1분 (폰/build-server)
7. rsync-from-gcp.sh                            ← 자동 1분
```

## 사용법

### Step 1 — bootstrap.sh (자동 시스템 셋업)

Ubuntu 첫 부팅 + Wi-Fi 연결 후:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tjjung-jtj/t490s-setup/main/t490s-bootstrap.sh)
```

자동: apt 패키지, SSH, Tailscale 설치, lid ignore, TLP 80%, PS1 초록.

### Step 2 — Tailscale 인증 (사용자)

```bash
sudo tailscale up
# 브라우저 Google 로그인 (build-server와 같은 계정)
```

### Step 3 — finalize.sh (전체 자동)

```bash
git clone https://github.com/tjjung-jtj/t490s-setup.git ~/work/t490s-setup
cd ~/work/t490s-setup
bash finalize.sh                  # 전체 (AI 모델 포함, 30~40분)
# 또는 옵션:
bash finalize.sh --no-models      # AI CLI 깔지만 모델 다운 스킵 (15분)
bash finalize.sh --no-ai          # AI CLI 자체 스킵
bash finalize.sh --no-bot         # trading-bot clone 스킵
```

자동:
- 한글 입력기 + talib 시스템 라이브러리
- GitHub SSH 키 생성 + 공개키 출력 (사용자가 GitHub 등록 후 Enter)
- trading-bot clone (dev 브랜치) + venv + pip install (talib 빌드 포함)
- 머신 가드 3단 자동 패치 (bot.py / rl_train.py / .gitignore)
- AI CLI 스택 설치 (`ai-cli-setup` repo 호출):
  - ollama + qwen2.5-coder:14b + llama3.1:8b
  - llm + plugins (gemini, groq, openrouter)
  - aider-chat
  - shell 단축키 (`ai`, `ai-fast`, `ai-smart`, `ai-local`, `ai-code`)
- llm API 키 build-server에서 scp 자동 복사 (재발급 0번)
- 외장 USB SSD 자동 마운트 (lsblk 확인 + ext4 포맷 옵션 + fstab UUID 등록)

### Step 4 — fcitx5 한글 입력기 GUI 등록 (사용자)

재로그인 → Settings → Region & Language → Input Sources → `+` → Korean → **Korean (Hangul)** 추가
한/영 토글: **Shift+Space**

### Step 5 — GCP authorized_keys 등록 (사용자, 폰 또는 build-server)

노트북 공개키 (finalize.sh가 출력함)를 GCP에 등록:

```bash
# 폰 Termius 또는 build-server에서:
ssh -i ~/.ssh/gcp_trading_bot_ed tjjung@34.169.93.135
echo '<노트북 공개키>' >> ~/.ssh/authorized_keys
exit
```

### Step 6 — rsync-from-gcp.sh (학습 데이터 가져오기)

```bash
bash ~/work/t490s-setup/rsync-from-gcp.sh
```

자동: state/learning/settings/strategy_weights/start_equity_by_market.json + models/ 전체 scp pull.

---

## Phase 1 — 학습 시작 (셋업 끝난 후)

```bash
cd ~/work/trading-bot && source .venv/bin/activate

# RL 첫 학습 (OCI A1 못 받아 못 돌리던 것, T490s에서 부활)
python3 rl_train.py        # 5코인 × 50 에피소드, 수시간~하룻밤

# XGBoost 24모델 BLAS 풀스레드 재학습
# (재학습 스크립트 참조)

# 검증 후 GCP scp 업로드
scp models/*.pkl tjjung@34.169.93.135:~/trading-bot/models/
```

---

## 안전장치

- **호스트명 `gcp*` 시 즉시 종료** (GCP 봇 서버 실수 방지)
- root 실행 금지 (sudo는 필요한 명령에만)
- 시스템 conf 수정 전 자동 백업 (`.bak.YYYYMMDD_HHMMSS`)
- 모든 단계 idempotent (재실행 안전)
- GitHub SSH 연결 검증 (등록 안 됐으면 finalize.sh 즉시 종료)

## 검증

```bash
# PS1 초록 (새 터미널)
echo $PS1

# 핵심 서비스
sudo systemctl status ssh tlp tailscaled

# Tailscale
tailscale ip -4

# AI CLI
llm keys                      # gemini/groq/openrouter 등록 확인
ai "hello"                    # AI 라우터 동작
ai-local "hello"              # 로컬 ollama

# trading-bot venv
cd ~/work/trading-bot && source .venv/bin/activate
python3 -c 'import xgboost, talib, ccxt; print("OK")'

# 머신 가드 동작
python3 -c 'import socket; print(socket.gethostname())'   # gcp* 가 아니어야
```

## 관련 repo

- [ai-cli-setup](https://github.com/tjjung-jtj/ai-cli-setup) — ollama + llm + aider 스택 (finalize.sh가 자동 호출)

## 파일

- `t490s-bootstrap.sh` — Step 1 자동 시스템 셋업
- `finalize.sh` — Step 3 한글/봇/AI/외장SSD 통합 자동
- `rsync-from-gcp.sh` — Step 6 GCP 학습 데이터 가져오기
- `MANUAL_STEPS.md` — 수동 7단계 디테일 (참고용, finalize.sh가 대부분 처리)
