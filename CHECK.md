# T490s Bootstrap 적용 상태 확인

T490s 터미널 (Ctrl+Alt+T)에서 아래 명령 하나씩 복사·붙여넣기·실행.

## 한 방에 다 확인 (권장)

```bash
curl -fsSL https://raw.githubusercontent.com/tjjung-jtj/t490s-setup/main/check.sh | bash
```

---

## 또는 한 줄씩 직접 확인

### [3] SSH 서버
```bash
systemctl is-active ssh
```
→ `active` 나와야 OK

```bash
ip -4 addr show | grep -oP "(?<=inet\s)\d+\.\d+\.\d+\.\d+" | grep -v 127.0.0.1
```
→ 집 LAN IP (예: 192.168.x.x) 출력되면 OK

### [4] Tailscale
```bash
which tailscale
```
→ `/usr/bin/tailscale` 같은 경로 출력되면 OK

```bash
systemctl is-active tailscaled
```
→ `active` 나와야 OK

```bash
tailscale ip -4
```
→ Tailscale IP 출력 안 되면 다음 명령으로 인증:
```bash
sudo tailscale up
```
→ 브라우저 열려 Google 로그인 (build-server랑 같은 계정)

### [5] Lid switch ignore (뚜껑 닫아도 안 꺼지게)
```bash
grep "^HandleLidSwitch" /etc/systemd/logind.conf
```
→ 3줄 모두 `=ignore` 나와야 OK

### [6] TLP 배터리 한도
```bash
systemctl is-active tlp
```
→ `active` OK

```bash
grep -E "^(START|STOP)_CHARGE_THRESH_BAT0" /etc/tlp.conf
```
→ START=75, STOP=80 출력되면 OK

### [7] PS1 초록색
```bash
grep "t490s green" ~/.bashrc
```
→ 한 줄 출력되면 OK. **새 터미널 열면** 프롬프트가 초록색으로 보임

### 가이드 파일
```bash
ls -la ~/T490S_NEXT_STEPS.md
```
→ 파일 있으면 OK

---

## 다 누락이거나 일부만 적용된 경우

bootstrap 다시 실행 (idempotent라 안전):
```bash
curl -fsSL https://raw.githubusercontent.com/tjjung-jtj/t490s-setup/main/t490s-bootstrap.sh | bash
```

---

## 다음 단계 (bootstrap 완료 후)

```bash
sudo tailscale up
```
→ 브라우저 열려 인증 후

```bash
curl -fsSL https://raw.githubusercontent.com/tjjung-jtj/t490s-setup/main/finalize.sh | bash
```
→ 한글 입력기 + trading-bot clone + AI CLI + 외장 SSD 마운트 등 자동
