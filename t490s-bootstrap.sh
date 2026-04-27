#!/usr/bin/env bash
# T490s Ubuntu 24.04 자동 셋업 스크립트
# 자동화 가능한 [2]~[7] 단계만 처리. 한글 입력기/Tailscale up/GitHub 키 등록은 수동.

set -euo pipefail

# ─── 색깔 출력 ───
GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; CYAN='\033[1;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }
hdr()  { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

# ─── 사전 점검 ───
if [[ $EUID -eq 0 ]]; then
    err "root로 실행 금지. 일반 사용자로 실행 (sudo는 스크립트가 필요할 때만 호출)."
    exit 1
fi

if ! command -v lsb_release &>/dev/null; then
    sudo apt-get install -y lsb-release
fi

UBUNTU_VERSION=$(lsb_release -rs)
log "Ubuntu $UBUNTU_VERSION 감지"

# 호스트명이 gcp- 면 절대 실행 금지 (사고 방지)
if [[ "$(hostname)" == gcp* ]]; then
    err "GCP 서버에서 이 스크립트 실행 금지!"
    exit 1
fi

warn "이 스크립트는 sudo 권한을 사용합니다. 비번 한 번 입력하면 진행됩니다."
sudo -v

# sudo keepalive (스크립트 끝까지 sudo 유지)
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

# ─── [2] 시스템 업데이트 + 기본 패키지 ───
hdr "[2] 시스템 업데이트 + 기본 패키지"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y \
    build-essential git vim htop tmux curl wget \
    python3-venv python3-pip python3-dev \
    openssh-server net-tools \
    rsync tree jq unzip \
    software-properties-common ca-certificates gnupg

log "기본 패키지 설치 완료"

# ─── [3] SSH 서버 ───
hdr "[3] SSH 서버 활성화"
sudo systemctl enable --now ssh
if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow ssh
fi
log "SSH 서버 활성화 완료. 집 LAN IP:"
ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '127.0.0.1' || true

# ─── [4] Tailscale 설치 (인증은 수동) ───
hdr "[4] Tailscale 설치"
if ! command -v tailscale &>/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
    log "Tailscale 설치 완료"
else
    log "Tailscale 이미 설치됨"
fi
warn "스크립트 종료 후 수동 실행: sudo tailscale up"
warn "  → 브라우저 열려 Google 로그인 (build-server와 같은 계정)"

# ─── [5] 뚜껑 닫아도 suspend 안 되게 ───
hdr "[5] Lid switch 무시 (24/7 운영)"
LOGIND_CONF=/etc/systemd/logind.conf
sudo cp "$LOGIND_CONF" "${LOGIND_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
sudo sed -i \
    -e 's/^#*HandleLidSwitch=.*/HandleLidSwitch=ignore/' \
    -e 's/^#*HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' \
    -e 's/^#*HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' \
    "$LOGIND_CONF"

# 키 누락 시 추가
for key in HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked; do
    if ! grep -qE "^${key}=ignore" "$LOGIND_CONF"; then
        echo "${key}=ignore" | sudo tee -a "$LOGIND_CONF" >/dev/null
    fi
done
sudo systemctl restart systemd-logind
log "Lid switch 무시 설정 완료"

# ─── [6] TLP 배터리 80% 한도 ───
hdr "[6] TLP 설치 + 배터리 80% 한도"
sudo apt-get install -y tlp tlp-rdw
TLP_CONF=/etc/tlp.conf
sudo cp "$TLP_CONF" "${TLP_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
sudo sed -i \
    -e 's/^#*START_CHARGE_THRESH_BAT0=.*/START_CHARGE_THRESH_BAT0=75/' \
    -e 's/^#*STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=80/' \
    "$TLP_CONF"

for kv in "START_CHARGE_THRESH_BAT0=75" "STOP_CHARGE_THRESH_BAT0=80"; do
    key="${kv%%=*}"
    if ! grep -qE "^${key}=" "$TLP_CONF"; then
        echo "$kv" | sudo tee -a "$TLP_CONF" >/dev/null
    fi
done

sudo systemctl enable --now tlp
log "TLP 설정 완료 (75-80% 충전 한도)"

# ─── [7] PS1 색 구분 (노트북=초록) ───
hdr "[7] PS1 초록색 (머신 시각 구분)"
PS1_LINE="export PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '  # t490s green"
if ! grep -qF "t490s green" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# T490s 머신 식별 - 초록 (GCP=빨강, build-server=노랑)" >> ~/.bashrc
    echo "$PS1_LINE" >> ~/.bashrc
    log "PS1 초록색 .bashrc에 추가됨"
else
    log "PS1 이미 추가됨 (스킵)"
fi

# ─── 마무리 ───
hdr "자동 셋업 완료"
cat <<'EOF'

수동으로 진행할 항목:
─────────────────────
1. sudo tailscale up  (브라우저 Google 로그인)

2. 한글 입력기 (재로그인 필요):
   sudo apt install -y fcitx5 fcitx5-hangul fcitx5-config-qt
   im-config -n fcitx5
   재로그인 → Settings → Region&Language → Korean(Hangul) 추가

3. GitHub SSH 키 생성 + 등록:
   ssh-keygen -t ed25519 -C "tjjung@gmail.com"
   cat ~/.ssh/id_ed25519.pub  # GitHub Settings → SSH keys

4. trading-bot clone + dev 브랜치:
   git clone git@github.com:tjjung-jtj/trading-bot.git
   cd trading-bot && git checkout -b dev
   python3 -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt

5. 머신 역할 가드 3단 (필수 - 사고 방지):
   bot.py 상단:
     import socket
     assert socket.gethostname().startswith('gcp'), 'bot.py는 GCP 전용'
   rl_train.py / backtest.py 상단:
     import socket
     assert not socket.gethostname().startswith('gcp'), 'GCP OOM, 노트북 전용'
   .gitignore: models/*.pkl, models/rl_dqn.json, *.bak_*

6. 외장 SSD 마운트:
   lsblk
   sudo mkdir -p /mnt/data
   sudo mount /dev/sdX1 /mnt/data
   sudo chown $USER:$USER /mnt/data

7. GCP → 노트북 rsync (state/learning/models)

설치 검증:
─────────
- 새 터미널 열어서 PS1 초록인지 확인
- sudo systemctl status ssh tlp tailscaled
- tailscale ip -4
EOF

log "다음 단계: 새 터미널 열어서 'source ~/.bashrc' 또는 재로그인"
