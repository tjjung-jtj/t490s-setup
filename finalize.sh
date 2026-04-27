#!/usr/bin/env bash
# T490s 셋업 — Tailscale 인증 + GitHub 등록 후 실행.
# 한글 입력기 / trading-bot / 머신 가드 / AI CLI 스택 / 외장 SSD까지 자동.
#
# 사용법:
#   bash finalize.sh                     # 전체 (AI 모델 포함, 30~40분)
#   bash finalize.sh --no-models         # AI 모델 다운 스킵 (15분)
#   bash finalize.sh --no-ai             # AI CLI 자체 스킵
#   bash finalize.sh --no-bot            # trading-bot clone 스킵

set -euo pipefail

# ─── flags ───
WITH_MODELS=1; WITH_AI=1; WITH_BOT=1
for arg in "$@"; do
    case "$arg" in
        --no-models) WITH_MODELS=0 ;;
        --no-ai) WITH_AI=0; WITH_MODELS=0 ;;
        --no-bot) WITH_BOT=0 ;;
        --help|-h) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown flag: $arg"; exit 2 ;;
    esac
done

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; CYAN='\033[1;36m'; NC='\033[0m'
log()   { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*" >&2; }
hdr()   { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }
pause() {
    [ "${SKIP_PAUSE:-0}" = "1" ] && { echo -e "${YELLOW}[?]${NC} $1 (SKIP_PAUSE=1, auto-skipped)"; return 0; }
    read -rp "$(echo -e ${YELLOW}[?]${NC} $1 [Enter to continue, Ctrl+C to abort]: )" _
}

# 안전 — root 금지, gcp* 금지
[[ $EUID -eq 0 ]] && { err "root로 실행 금지"; exit 1; }
[[ "$(hostname)" == gcp* ]] && { err "GCP 서버에서 실행 금지!"; exit 1; }

sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

# ─── [1] 한글 입력기 + talib 시스템 라이브러리 ───
hdr "[1] 한글 입력기 + talib 시스템 라이브러리"
sudo apt-get update -qq
sudo apt-get install -y \
    fcitx5 fcitx5-hangul fcitx5-config-qt \
    libta-lib0 libta-lib-dev || \
sudo apt-get install -y \
    fcitx5 fcitx5-hangul fcitx5-config-qt \
    libta-lib0t64 libta-lib0t64-dev   # Ubuntu 24.04 대체 패키지명
im-config -n fcitx5 || true
log "한글 입력기 + talib 라이브러리 설치 완료"
warn "주의: 한글 입력기 활성화는 재로그인 후 GUI Settings → Input Sources → Korean(Hangul) 추가 필요"

# ─── [2] GitHub SSH 키 ───
hdr "[2] GitHub SSH 키"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "tjjung@gmail.com" -f ~/.ssh/id_ed25519 -N ""
    log "SSH 키 생성됨"
else
    log "SSH 키 이미 존재"
fi

git config --global user.email "tjjung@gmail.com" 2>/dev/null || true
git config --global user.name "tjjung-jtj" 2>/dev/null || true

echo
echo -e "${CYAN}=== GitHub에 등록할 공개키 ===${NC}"
cat ~/.ssh/id_ed25519.pub
echo
echo -e "${YELLOW}이 키를 https://github.com/settings/keys 에 등록하세요 (이름: t490s).${NC}"
pause "GitHub 등록 끝났나요?"

# 검증
if ssh -o BatchMode=yes -o ConnectTimeout=8 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    log "GitHub SSH 연결 OK"
else
    err "GitHub SSH 연결 실패. 키 등록 확인 후 재실행."
    exit 1
fi

# ─── [3] trading-bot clone + venv + 머신 가드 ───
if [ "$WITH_BOT" -eq 1 ]; then
    hdr "[3] trading-bot clone + dev 브랜치 + venv"
    mkdir -p ~/work
    if [ ! -d ~/work/trading-bot ]; then
        cd ~/work
        git clone git@github.com:tjjung-jtj/trading-bot.git
        cd trading-bot
        git checkout -b dev || git checkout dev
    else
        cd ~/work/trading-bot
        log "trading-bot 이미 clone됨, dev 브랜치 확인"
        git checkout dev 2>/dev/null || git checkout -b dev
    fi

    if [ ! -d .venv ]; then
        python3 -m venv .venv
    fi
    source .venv/bin/activate
    pip install --upgrade pip --quiet
    pip install -r requirements.txt
    log "trading-bot venv + 패키지 설치 완료"

    # ─── [4] 머신 가드 3단 자동 패치 ───
    hdr "[4] 머신 가드 3단 (사고 방지)"

    # bot.py 가드
    if ! grep -q "GCP 전용" bot.py 2>/dev/null; then
        python3 - <<'PYEOF'
src = open('bot.py').read()
guard = """import socket
assert socket.gethostname().startswith('gcp'), 'bot.py는 GCP 전용 (노트북에서 실수로 매매 켜짐 방지)'
"""
# 첫 import 다음에 삽입
import re
m = re.search(r'^(import\s+\w+|from\s+\w+\s+import\s+\w+)', src, re.M)
if m:
    pos = src.find('\n', m.end()) + 1
    src = src[:pos] + guard + src[pos:]
    open('bot.py', 'w').write(src)
    print('bot.py 가드 추가')
else:
    print('bot.py import 못 찾음 — skip')
PYEOF
    else
        log "bot.py 가드 이미 적용됨"
    fi

    # rl_train.py / backtest.py 가드 (있으면)
    for f in rl_train.py backtest.py; do
        if [ -f "$f" ] && ! grep -q "GCP는 1GB라 학습 OOM" "$f" 2>/dev/null; then
            python3 - "$f" <<'PYEOF'
import sys, re
fp = sys.argv[1]
src = open(fp).read()
guard = """import socket
assert not socket.gethostname().startswith('gcp'), 'GCP는 1GB라 학습 OOM. 노트북 전용'
"""
m = re.search(r'^(import\s+\w+|from\s+\w+\s+import\s+\w+)', src, re.M)
if m:
    pos = src.find('\n', m.end()) + 1
    src = src[:pos] + guard + src[pos:]
    open(fp, 'w').write(src)
    print(f'{fp} 가드 추가')
PYEOF
        fi
    done

    # .gitignore 추가
    for pat in 'models/*.pkl' 'models/rl_dqn.json' '*.bak_*' '.venv/'; do
        if ! grep -qxF "$pat" .gitignore 2>/dev/null; then
            echo "$pat" >> .gitignore
        fi
    done
    log ".gitignore 갱신"
fi

# ─── [5] AI CLI 스택 (ollama + llm + aider) ───
if [ "$WITH_AI" -eq 1 ]; then
    hdr "[5] AI CLI 스택 (ai-cli-setup repo)"
    if [ ! -d ~/work/ai-cli-setup ]; then
        git clone https://github.com/tjjung-jtj/ai-cli-setup.git ~/work/ai-cli-setup
    fi
    cd ~/work/ai-cli-setup
    if [ "$WITH_MODELS" -eq 1 ]; then
        ./install-ai-cli.sh
    else
        ./install-ai-cli.sh --tools-only
        warn "AI 모델 다운로드 스킵됨 — 나중에: cd ~/work/ai-cli-setup && ./install-ai-cli.sh --models-only"
    fi

    # ─── [6] llm 키 build-server에서 복사 (Tailscale 통해) ───
    hdr "[6] llm API 키 build-server에서 복사"
    mkdir -p ~/.config/io.datasette.llm
    BS_HOST="${BS_HOST:-jtj@build-server}"  # 환경변수로 호스트 지정 가능
    if scp -o BatchMode=yes -o ConnectTimeout=8 \
        "$BS_HOST:~/.config/io.datasette.llm/keys.json" \
        ~/.config/io.datasette.llm/keys.json 2>/dev/null; then
        chmod 600 ~/.config/io.datasette.llm/keys.json
        log "build-server에서 keys.json 복사 완료"
        ~/.local/bin/llm keys 2>/dev/null | sed 's/^/  /' || true
    else
        warn "build-server scp 실패 — Tailscale 인증 안 됐거나 호스트 별칭(${BS_HOST}) 미설정."
        warn "수동 실행: scp ${BS_HOST}:~/.config/io.datasette.llm/keys.json ~/.config/io.datasette.llm/"
        warn "또는 새로 발급: cd ~/work/ai-cli-setup && ./setup-ai-keys.sh"
    fi
fi

# ─── [7] 외장 SSD 마운트 (선택, 사용자 확인 필요) ───
hdr "[7] 외장 USB SSD 마운트 (선택)"
echo "현재 lsblk:"
lsblk -f
echo
echo -e "${YELLOW}외장 USB SSD 꽂혀 있으면 장치명을 입력하세요 (예: sdb1).${NC}"
echo -e "${YELLOW}없거나 스킵하려면 그냥 Enter.${NC}"
read -rp "장치명 (sdX1 형식, 또는 Enter로 스킵): " DEV || DEV=""
if [ -n "$DEV" ]; then
    DEVPATH="/dev/${DEV#/dev/}"
    if [ ! -b "$DEVPATH" ]; then
        err "$DEVPATH 가 블록 장치가 아님. 스킵."
    else
        FSTYPE=$(lsblk -no FSTYPE "$DEVPATH" 2>/dev/null || echo "")
        echo "현재 FSTYPE: ${FSTYPE:-none}"
        if [ "$FSTYPE" != "ext4" ]; then
            warn "ext4 아님 — 데이터 백업 후 포맷해야 합니다."
            read -rp "$DEVPATH 를 ext4로 포맷하고 마운트할까요? (안의 데이터 다 지워짐) [y/N]: " ans || ans=""
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                sudo umount "$DEVPATH" 2>/dev/null || true
                sudo mkfs.ext4 -L data "$DEVPATH"
                log "ext4 포맷 완료"
            else
                warn "포맷 취소 — 외장 SSD 단계 스킵"
                DEV=""
            fi
        fi
    fi

    if [ -n "$DEV" ]; then
        sudo mkdir -p /mnt/data
        sudo mount "$DEVPATH" /mnt/data
        sudo chown "$USER:$USER" /mnt/data
        log "마운트: $DEVPATH → /mnt/data"

        # fstab 영구 등록
        UUID=$(sudo blkid -s UUID -o value "$DEVPATH")
        if [ -n "$UUID" ] && ! grep -q "$UUID" /etc/fstab; then
            echo "UUID=$UUID /mnt/data ext4 defaults,nofail,x-systemd.automount 0 2" | sudo tee -a /etc/fstab >/dev/null
            log "fstab 등록 (nofail + automount)"
        fi
    fi
fi

# ─── 마무리 ───
hdr "finalize.sh 완료"
cat <<EOF

다음 수동 단계 (남은 것):

1. ${CYAN}fcitx5 한글 입력기 GUI 등록${NC} (재로그인 필요):
   재로그인 → Settings → Region & Language → Input Sources → + → Korean → Korean(Hangul)

2. ${CYAN}GCP + OCI #2 authorized_keys에 노트북 키 추가${NC} (양쪽 rsync 위해):
   - 노트북 공개키:
$(sed 's/^/     /' ~/.ssh/id_ed25519.pub)

   GCP 등록 (폰 Termius 또는 build-server에서):
     ssh -i ~/.ssh/gcp_trading_bot_ed tjjung@34.169.93.135
     echo '<위 공개키>' >> ~/.ssh/authorized_keys
     exit

   OCI #2 등록 (GCP 경유 또는 폰 Termius로 직접):
     ssh -i ~/.ssh/gcp_trading_bot_ed tjjung@34.169.93.135
     ssh -i ~/.ssh/oci_key ubuntu@152.69.212.45
     echo '<위 공개키>' >> ~/.ssh/authorized_keys
     exit; exit

3. ${CYAN}rsync 양쪽 실행 (GCP + OCI #2 paper)${NC}:
   bash ~/work/t490s-setup/rsync-from-gcp.sh    # GCP 일반 시장 + scalp
   bash ~/work/t490s-setup/rsync-from-oci2.sh   # OCI #2 HR 시장 + scalp
   → 양쪽 학습 데이터 모두 노트북에 누적

상태 확인:
  - llm keys                          # llm 키 목록
  - ai "hello"                        # AI 라우터 동작
  - cd ~/work/trading-bot && source .venv/bin/activate && python3 -c 'import xgboost, talib'
EOF
log "끝."
