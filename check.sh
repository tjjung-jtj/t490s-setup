#!/usr/bin/env bash
# T490s bootstrap 적용 상태 확인 스크립트
# 사용: curl -fsSL https://raw.githubusercontent.com/tjjung-jtj/t490s-setup/main/check.sh | bash

set +e

GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
fail() { echo -e "${RED}[NG]${NC} $*"; }
info() { echo -e "${CYAN}[i]${NC} $*"; }

echo
info "━━━ T490s bootstrap 적용 상태 ━━━"
echo

info "[3] SSH 서버"
systemctl is-active --quiet ssh && ok "ssh active" || fail "ssh INACTIVE"
ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '127.0.0.1' | sed 's/^/    LAN IP: /'

echo
info "[4] Tailscale"
command -v tailscale &>/dev/null && ok "tailscale installed" || fail "tailscale NOT installed"
systemctl is-active --quiet tailscaled && ok "tailscaled active" || fail "tailscaled INACTIVE"
if command -v tailscale &>/dev/null; then
    TS_IP=$(tailscale ip -4 2>/dev/null | head -1)
    [ -n "$TS_IP" ] && ok "tailscale up (IP: $TS_IP)" || fail "tailscale NOT up — sudo tailscale up 필요"
fi

echo
info "[5] Lid switch ignore"
LID=$(grep -E "^HandleLidSwitch" /etc/systemd/logind.conf 2>/dev/null)
if [ -n "$LID" ]; then
    echo "$LID" | sed 's/^/    /'
    echo "$LID" | grep -q "ignore" && ok "lid ignore 적용" || fail "lid ignore 누락"
else
    fail "HandleLidSwitch 설정 없음"
fi

echo
info "[6] TLP 배터리 한도"
systemctl is-active --quiet tlp && ok "tlp active" || fail "tlp INACTIVE"
if [ -f /etc/tlp.conf ]; then
    grep -E "^(START|STOP)_CHARGE_THRESH_BAT0" /etc/tlp.conf | sed 's/^/    /'
fi

echo
info "[7] PS1 초록색"
grep -q "t490s green" ~/.bashrc && ok ".bashrc에 박힘" || fail ".bashrc 누락"

echo
info "[수동 가이드 파일]"
[ -f ~/T490S_NEXT_STEPS.md ] && ok "~/T490S_NEXT_STEPS.md 있음 ($(stat -c%s ~/T490S_NEXT_STEPS.md) bytes)" || fail "~/T490S_NEXT_STEPS.md 없음"

echo
info "━━━ 결과 요약 ━━━"
echo "  - 모두 OK면 bootstrap 완료. sudo tailscale up 진행 가능"
echo "  - NG 항목 있으면 다음 명령으로 재실행 가능 (idempotent):"
echo "      curl -fsSL https://raw.githubusercontent.com/tjjung-jtj/t490s-setup/main/t490s-bootstrap.sh | bash"
echo
