# Step 2 — bootstrap.sh 실행 (T490s 본체에서)

시스템 레벨 셋업: apt 패키지, lid 닫아도 suspend 방지, TLP 80%, ssh keepalive 등.

이미 ssh / tailscale / git이 깔려있어도 idempotent해서 안전합니다.

## T490s 본체 터미널에서 한 줄

```bash
cd ~/t490s-setup && bash t490s-bootstrap.sh
```

## 도중에 일어날 일

1. **sudo 비번 입력 prompt** 한 번 등장 → 비번(`5747`) 입력
2. 그 후 5~10분 자동 진행 — apt update/upgrade, 패키지 설치, lid ignore, TLP 설정 등
3. 끝나면 화면에 `=== bootstrap 완료 ===` 같은 메시지

## 진행 단계 (스크립트 안에 들어있는 것들)

| 단계 | 내용 |
|---|---|
| [2] | 시스템 업데이트 + 기본 패키지 (build-essential, git, vim, htop, tmux, python3-venv, openssh-server, jq 등) |
| [3] | SSH 서버 활성화 (이미 됐으면 패스) |
| [4] | Tailscale 설치 (이미 깔려 있으면 패스) |
| [5] | 뚜껑 닫아도 suspend 방지 (`HandleLidSwitch=ignore`) ← 백테스트 돌리는 동안 필수 |
| [6] | TLP 설치 + 배터리 80% 충전 한도 (T490s 배터리 수명 보호) |
| [7] | bash PS1 초록색 (build-server와 시각적 구분) |

## 끝난 후

`=== bootstrap 완료 ===` 메시지 보이면 build-server 측 Claude에게 "**bootstrap 완료**" 알려주세요.

다음 단계(finalize.sh)는 별도 안내 드립니다.

## 만약 에러가 나면

화면에 빨간색 `[x]` 메시지로 출력됨. 그 메시지를 그대로 복사해서 알려주시면 진단합니다.
