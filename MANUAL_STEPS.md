# T490s 수동 셋업 7단계

자동 셋업 (`t490s-bootstrap.sh`) 끝난 다음 진행할 것들.
한 단계씩 차례대로. 막히면 폰 텔레그램 또는 build-server Claude에 물어보기.

> 노트북에서 이 파일 보는 법:
> - `cat ~/T490S_NEXT_STEPS.md` (터미널)
> - `gedit ~/T490S_NEXT_STEPS.md` (GUI 편집기)
> - `firefox https://github.com/tjjung-jtj/t490s-setup/blob/main/MANUAL_STEPS.md` (브라우저)

---

## 1. Tailscale 인증 (외부망 ssh용)

```bash
sudo tailscale up
```
→ 브라우저가 자동으로 열림. **build-server와 같은 Google 계정**으로 로그인.
폰에도 Tailscale 앱 설치 후 같은 계정 로그인.

확인:
```bash
tailscale ip -4    # 100.x.y.z 형태 IP 출력되면 성공
tailscale status   # 다른 노드(build-server, GCP) 보여야 함
```

---

## 2. 한글 입력기 (fcitx5)

```bash
sudo apt install -y fcitx5 fcitx5-hangul fcitx5-config-qt
im-config -n fcitx5
```

**재로그인 필수** (logout 후 다시 login).

재로그인 후:
- Settings → Region & Language → Manage Installed Languages (필요 시)
- Settings → Keyboard → Input Sources → `+` → Korean → **Korean (Hangul)** 추가
- 한/영 토글: **Shift + Space** (또는 노트북 한/영 키)

테스트: 아무 텍스트박스에서 한/영 토글로 한글 입력 확인.

---

## 3. GitHub SSH 키 생성 + 등록

```bash
ssh-keygen -t ed25519 -C "tjjung@gmail.com"
# 엔터 3번 (경로 default, 비번 없음)

cat ~/.ssh/id_ed25519.pub
# 출력 전체 복사
```

브라우저에서:
1. https://github.com/settings/keys 접속
2. **New SSH key** 클릭
3. Title: `t490s` / Key: 위에서 복사한 내용 붙여넣기
4. **Add SSH key**

연결 확인:
```bash
ssh -T git@github.com
# Hi tjjung-jtj! You've successfully authenticated... 나오면 성공

git config --global user.email "tjjung@gmail.com"
git config --global user.name "tjjung-jtj"
```

---

## 4. trading-bot clone + dev 브랜치 + venv

```bash
mkdir -p ~/work && cd ~/work
git clone git@github.com:tjjung-jtj/trading-bot.git
cd trading-bot

# 노트북은 dev 브랜치에서 작업 (GCP main과 분리)
git checkout -b dev

# Python 가상환경
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

---

## 5. 머신 역할 가드 3단 (사고 방지 — 절대 빠뜨리지 말 것)

**(a) bot.py 상단** (1번째 import 다음 줄에 추가):
```python
import socket
assert socket.gethostname().startswith('gcp'), 'bot.py는 GCP 전용 (노트북에서 실수로 매매 켜짐 방지)'
```

**(b) rl_train.py / backtest.py 상단**:
```python
import socket
assert not socket.gethostname().startswith('gcp'), 'GCP는 1GB라 학습 OOM. 노트북 전용'
```

**(c) .gitignore에 추가**:
```
models/*.pkl
models/rl_dqn.json
*.bak_*
.venv/
```

이미 git에 추적되고 있으면:
```bash
git rm --cached models/*.pkl 2>/dev/null
git rm --cached models/rl_dqn.json 2>/dev/null
git add .gitignore
git commit -m "guard: machine-role isolation + ignore models"
git push origin dev
```

---

## 6. 외장 SSD 마운트

USB 외장 SSD 꽂고:

```bash
lsblk
# 보통 /dev/sdb1 또는 /dev/sdc1. SIZE 보고 외장 식별.

sudo mkdir -p /mnt/data
sudo mount /dev/sdX1 /mnt/data    # X를 실제 글자로
sudo chown $USER:$USER /mnt/data

# 마운트 확인
df -h /mnt/data
```

영구 마운트 (`/etc/fstab` 등록):
```bash
# UUID 확인
sudo blkid /dev/sdX1
# UUID="abc-123-..." TYPE="ext4" 출력 복사

# /etc/fstab 편집
sudo nano /etc/fstab
# 아래 줄 추가 (UUID·TYPE 실제값으로):
UUID=abc-123-... /mnt/data ext4 defaults,nofail,x-systemd.automount 0 2
```
**`nofail,x-systemd.automount` 옵션 필수** — 외장 분리해도 부팅 안 멈춤.

---

## 7. GCP → 노트북 rsync (학습 데이터 받기)

GCP에 노트북 ssh 키 등록부터:
```bash
# 노트북에서 공개키 출력
cat ~/.ssh/id_ed25519.pub
```

build-server(또는 폰)에서 GCP에 접속해 노트북 키 추가:
```bash
ssh -i ~/.ssh/gcp_trading_bot_ed tjjung@34.169.93.135
echo "<노트북 공개키 내용>" >> ~/.ssh/authorized_keys
exit
```

노트북에서 rsync:
```bash
cd ~/work/trading-bot
rsync -avz tjjung@34.169.93.135:~/trading-bot/state.json ./
rsync -avz tjjung@34.169.93.135:~/trading-bot/learning.json ./
rsync -avz tjjung@34.169.93.135:~/trading-bot/models/ ./models/
```

---

## 검증

```bash
# 새 터미널 열기 → PS1 초록색 확인
echo $PS1

# 핵심 서비스 동작 확인
sudo systemctl status ssh tlp tailscaled

# Tailscale 연결 확인
tailscale ip -4
tailscale status

# trading-bot venv 동작
cd ~/work/trading-bot && source .venv/bin/activate && python3 -c "import xgboost, talib; print('OK')"
```

---

## 다음 단계: Phase 1 (RL 학습 첫 가치 작업)

```bash
cd ~/work/trading-bot && source .venv/bin/activate

# RL 첫 학습 (5코인 × 50 에피소드, 수시간~하룻밤)
python3 rl_train.py

# XGBoost 24개 .pkl 일괄 재학습 (BLAS 풀스레드)
# (스크립트는 trading-bot 안에 따로)

# 모델 검증 후 GCP scp 업로드
scp models/*.pkl tjjung@34.169.93.135:~/trading-bot/models/
```

자세한 내용: `~/work/CLAUDE.md` 또는 메모리 `home_minipc_plan.md` / `trading_bot_gcp_notebook_split.md` 참조.
