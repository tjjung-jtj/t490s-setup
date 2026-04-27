# 절전 / 화면 잠금 끄기

작업 도중 화면 꺼지거나 잠금 걸리지 않게.

## T490s 터미널에 한 줄씩 카피

### 1) 화면 절전 끄기
```bash
gsettings set org.gnome.desktop.session idle-delay 0
```

### 2) 화면 잠금 끄기
```bash
gsettings set org.gnome.desktop.screensaver lock-enabled false
```

### 3) 확인
```bash
gsettings get org.gnome.desktop.session idle-delay && gsettings get org.gnome.desktop.screensaver lock-enabled
```

3번 결과로 `uint32 0`, `false` 가 출력되면 성공.
