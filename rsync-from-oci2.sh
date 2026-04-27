#!/usr/bin/env bash
# OCI #2 (152.69.212.45)에서 trading-bot paper 학습 데이터를 노트북으로 가져옴.
# GCP 데이터는 rsync-from-gcp.sh로 별도. 양쪽 합산 학습용.
# 실행 전 OCI #2 authorized_keys에 노트북 ssh 공개키 등록 필요.
#
# 사용법:
#   bash rsync-from-oci2.sh

set -euo pipefail

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }

OCI="${OCI:-ubuntu@152.69.212.45}"
DEST="${DEST:-$HOME/work/trading-bot/data-oci2}"

[[ "$(hostname)" == gcp* ]] && { err "GCP 서버에서 실행 금지!"; exit 1; }
mkdir -p "$DEST"

# 첫 접속 known_hosts 등록
log "OCI #2 ssh 연결 확인..."
if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$OCI" 'echo connected' >/dev/null 2>&1; then
    err "OCI #2 ssh 실패. authorized_keys 등록 확인:"
    err "  공개키: $(cat ~/.ssh/id_ed25519.pub)"
    err "  OCI #2에 등록: ssh ${OCI} (현재 안 됨)"
    err "  → 폰 Termius 또는 build-server에서 OCI #2 접속 후 authorized_keys 추가"
    err "  → 또는 GCP 경유: ssh -i ~/.ssh/gcp_trading_bot_ed tjjung@34.169.93.135"
    err "                   → ssh -i ~/.ssh/oci_key ubuntu@152.69.212.45 'echo \"<공개키>\" >> ~/.ssh/authorized_keys'"
    exit 1
fi
log "OCI #2 연결 OK"

# 핵심 데이터 파일 — GCP와 동일하지만 OCI #2 paper 자체 누적된 별도 데이터
FILES=(state.json learning.json settings.json strategy_weights.json start_equity_by_market.json)
for f in "${FILES[@]}"; do
    if rsync -avz --partial -e 'ssh -o ConnectTimeout=10' "${OCI}:~/trading-bot/${f}" "${DEST}/${f}" 2>/dev/null; then
        log "OCI #2 $f"
    else
        warn "OCI #2 $f 못 가져옴 (없거나 실패)"
    fi
done

# OCI #2 paper는 모델 학습 안 함 (GCP 모델 그대로 inference) — models/ 스킵.
# 만약 필요하면 추가.

# 검증
echo
log "OCI #2 데이터:"
ls -la "$DEST"/*.json 2>/dev/null | awk '{print "  ", $5, $9}'

cat <<EOF

==============================================
양쪽 데이터 위치
==============================================
  GCP (일반 시장):  ~/work/trading-bot/         (rsync-from-gcp.sh)
  OCI #2 (HR 시장): $DEST                       (이 스크립트)

학습 시 양쪽 trade_records 합산:
  python3 -c "
  import json
  gcp = json.load(open('~/work/trading-bot/learning.json'))['trade_records']
  oci2 = json.load(open('$DEST/learning.json'))['trade_records']
  combined = gcp + oci2
  print(f'GCP: {len(gcp)} | OCI #2: {len(oci2)} | 합산: {len(combined)}')
  "

차이:
  - GCP trade_records: 일반 시장 (crypto, us, kr) — balanced preset
  - OCI #2 trade_records: HR 시장 (crypto_hr, us_hr, kr_hr) — aggressive preset
  - scalp는 양쪽 다 (분담 안 함)
==============================================
EOF
