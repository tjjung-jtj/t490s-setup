# T490s에 build-server SSH 키 등록

build-server에서 ssh로 T490s 접속하기 위한 1회성 등록 작업.

T490s 터미널에서 아래 명령 한 줄 복사 → 붙여넣기 → 엔터.

## 한 줄 명령 (이거 하나만 카피)

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh && curl -s https://raw.githubusercontent.com/tjjung-jtj/t490s-setup/main/build-server-pubkey.txt >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo "===등록 완료===" && cat ~/.ssh/authorized_keys
```

## 이 명령이 하는 일

1. `mkdir -p ~/.ssh` — `.ssh` 폴더 없으면 생성
2. `chmod 700 ~/.ssh` — 폴더 권한 (본인만 접근)
3. `curl -s ... >> ~/.ssh/authorized_keys` — GitHub에서 build-server 공개키 다운받아 authorized_keys에 추가
4. `chmod 600 ~/.ssh/authorized_keys` — 파일 권한 (본인만 읽기/쓰기)
5. `cat ~/.ssh/authorized_keys` — 등록 결과 확인용 출력

## 성공 화면

명령 끝에 아래처럼 출력되면 성공:

```
===등록 완료===
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINsDvoyDZfzH90vcXRWw4zlHpvbajo71nGJCOxbQO7s3 tjjung@gmail.com
```

## 다음 단계

등록 끝나면 build-server 측 Claude에게 "완료" 알려주면, ssh 접속 검증 후 `finalize.sh` 자동 실행 시작.
