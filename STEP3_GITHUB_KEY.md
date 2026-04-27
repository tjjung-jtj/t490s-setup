# Step 3 — T490s SSH 키 GitHub 등록

T490s가 trading-bot/ai-cli-setup 같은 개인 GitHub repo를 clone하려면 SSH 키 등록이 필요합니다.

## 1) 공개키 카피

이 페이지에서 카피:
**https://github.com/tjjung-jtj/t490s-setup/blob/main/t490s-pubkey.txt**

또는 raw URL의 한 줄 통째로:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMtI5IiS3S7URPJ6F16FdymLqVMaeR2UVn1tNzj9sleI tjjung@gmail.com
```

## 2) GitHub 키 등록 페이지

폰 브라우저(또는 노트북 브라우저)로 접속 — `tjjung-jtj` 계정 로그인 상태에서:

**https://github.com/settings/keys**

## 3) 등록

1. **New SSH key** 버튼 클릭
2. **Title**: `t490s`
3. **Key type**: `Authentication Key` (기본값 그대로)
4. **Key**: 위에서 카피한 공개키 한 줄 붙여넣기
5. **Add SSH key** 클릭
6. (GitHub 비번 또는 2FA 한 번 확인할 수도)

## 4) 등록 끝나면

build-server 측 Claude에게 "**GitHub 등록 완료**" 알려주세요. ssh 검증 후 finalize.sh 나머지 자동 진행 (20~30분).
