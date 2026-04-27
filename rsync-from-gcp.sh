#!/usr/bin/env bash
# GCP에서 trading-bot 학습 데이터/모델을 노트북으로 가져옴.
# 실행 전 GCP authorized_keys에 노트북 ssh 공개키 등록 필요.
#
# 사용법:
#   bash rsync-from-gcp.sh

set -euo pipefail

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }

GCP="${GCP:-tjjung@34.169.93.135}"
DEST="${DEST:-$HOME/work/trading-bot}"

[[ "$(hostname)" == gcp* ]] && { err "GCP 서버에서 실행 금지!"; exit 1; }
[ -d "$DEST" ] || { err "$DEST 없음 — finalize.sh 먼저 실행하세요."; exit 1; }

cd "$DEST"

# 첫 접속 known_hosts 등록
log "GCP ssh 연결 확인..."
if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$GCP" 'echo connected' >/dev/null 2>&1; then
    err "GCP ssh 실패. authorized_keys 등록 확인:"
    err "  공개키: $(cat ~/.ssh/id_ed25519.pub)"
    err "  GCP에 등록: ssh -i ~/.ssh/gcp_trading_bot_ed tjjung@34.169.93.135 && echo '<위 공개키>' >> ~/.ssh/authorized_keys"
    exit 1
fi
log "GCP 연결 OK"

# 핵심 데이터 파일들
FILES=(state.json learning.json settings.json strategy_weights.json start_equity_by_market.json)
for f in "${FILES[@]}"; do
    if rsync -avz --partial -e 'ssh -o ConnectTimeout=10' "${GCP}:~/trading-bot/${f}" "./${f}" 2>/dev/null; then
        log "$f"
    else
        warn "$f 못 가져옴 (없거나 실패)"
    fi
done

# models/ 디렉토리 (XGBoost .pkl 등)
log "models/ rsync..."
mkdir -p ./models
rsync -avz --partial --exclude='*.tmp' -e 'ssh -o ConnectTimeout=10' \
    "${GCP}:~/trading-bot/models/" ./models/ || warn "models 일부 실패"

# 검증
echo
log "가져온 파일:"
ls -la state.json learning.json settings.json 2>/dev/null | awk '{print "  ", $5, $9}'
echo
log "models/:"
ls -la models/ | head -10

cat <<EOF

다음 단계:

1. ${YELLOW}머신 가드 동작 확인${NC}:
   python3 -c 'import socket; print("hostname:", socket.gethostname())'
   # gcp* 가 아니어야 함

2. ${YELLOW}Phase 1 학습 시작${NC} (RL 부활):
   cd ~/work/trading-bot
   source .venv/bin/activate
   python3 rl_train.py        # 5코인 × 50 에피소드, 수시간~하룻밤

3. ${YELLOW}XGBoost 24모델 일괄 재학습${NC}:
   (재학습 스크립트 참조)

4. ${YELLOW}모델 검증 후 GCP scp 업로드${NC}:
   scp models/*.pkl ${GCP}:~/trading-bot/models/

자세한 흐름: \`~/work/CLAUDE.md\` 또는 메모리 \`home_minipc_plan.md\` / \`trading_bot_gcp_notebook_split.md\`
EOF
