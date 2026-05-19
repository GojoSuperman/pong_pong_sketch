# 🎨 퐁퐁 스케치: 몽이의 파스텔 모험 (Pong Pong Sketch)

> _흑백의 세상을 한 발 한 발 파스텔톤으로 물들이는, 둥글둥글 귀여운 캐주얼 플랫포머._

**Flutter** + **Flame 게임 엔진**으로 개발한 **포트폴리오용 2D 캐주얼 플랫포머 게임**입니다.
주인공 '몽이'가 흑백 발판을 밟아 세상을 파스텔톤으로 채우며 정상까지 올라가는 짧은 한 스테이지를 담고 있습니다.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Flame-1.37-FF6B35?logo=flame&logoColor=white" alt="Flame" />
  <img src="https://img.shields.io/badge/Platform-Web-FAF8F5?logo=googlechrome&logoColor=2B2B2B" alt="Web" />
  <img src="https://img.shields.io/badge/flutter_analyze-0_issues-B8E6D2?logoColor=2B2B2B" alt="0 issues" />
</p>

<p align="center">
  <a href="https://gojosuperman.github.io/pong_pong_sketch/">
    <img src="https://img.shields.io/badge/▶_지금_플레이하기-PLAY_NOW-FFB3C6?style=for-the-badge&logoColor=2B2B2B" alt="Play Now" />
  </a>
</p>

<p align="center">
  <sub>설치 없이 브라우저에서 바로 플레이 → <a href="https://gojosuperman.github.io/pong_pong_sketch/">gojosuperman.github.io/pong_pong_sketch</a></sub>
</p>

---

## ✨ 핵심 게임 기믹 (Core Gameplay)

### 🌈 세상을 물들이는 컬러 기믹

이 게임의 알파이자 오메가. 모든 발판은 처음엔 **흑백(Monochrome)** — 검은 외곽선과 흰 면뿐입니다.
몽이가 발판 위에 안착하는 순간, 발판은 자신의 고유 번호(`index`)에 따라 **고유한 파스텔톤으로 활성화**됩니다.

| 발판 상태 | 설명 | 비주얼 |
| :--- | :--- | :--- |
| `monochrome` | 밟기 전 — 검은 외곽선 + 흰 면 | ⬜ |
| `colored` | 밟은 후 — 팔레트 순환으로 채색 | 🩷 핑크 / 🌿 민트 / 💛 옐로우 |

### 🎮 캐주얼 물리 엔진

직접 구현한 가벼운 물리·충돌 로직으로 손맛 있는 조작감을 만들었습니다.

| 기능 | 설명 |
| :--- | :--- |
| 🦘 **부드러운 2단 점프** | 1단은 강하게, 2단은 살짝 약하게 — 공중 제어가 자연스러운 점프 곡선 |
| 💥 **머리 충돌 (Head Bump)** | 발판 밑면을 들이받으면 상승이 막히고 아래로 살짝 튕겨 낙하 |
| ⬆️ **단방향 발판 착지** | 아래에서 점프하면 발판을 통과, 위에서 떨어질 때만 착지 |
| 🏆 **승리 / 패배 루프** | 최종 발판 도달 시 클리어 배너, 낙사 시 페이드 연출 후 리셋 |

### 🕹️ 조작법

| 키 | 동작 |
| :--- | :--- |
| `A` / `D` 또는 `←` / `→` | 좌우 이동 |
| `Space` 또는 `↑` | 점프 (공중에서 한 번 더 → 2단 점프) |

---

## 🛠️ 기술적 도전 및 해결 (Technical Achievements)

### 1. Flame 1.x 최신 구조 준수 — Y축 전용 카메라 트래킹

레거시 `camera` API 대신 Flame 1.x의 **`World` + `CameraComponent`** 구조를 채택했습니다.
모든 게임 오브젝트를 `world`에 배치하고, `camera.follow(player, verticalOnly: true)`로
**좌우 흔들림 없이 세로축으로만** 몽이를 부드럽게 추적하도록 구현했습니다.

### 2. 결정적 상태 머신 기반 연출 (Juice)

낙사 시 화면이 거칠게 튀지 않도록 **페이드 인/아웃 오버레이**를 추가했습니다.
핵심은 **타이머·`Future` 없이 `update` 기반 상태 머신**으로 설계해
비동기 꼬임(Race Condition)을 원천 차단한 점입니다.

```
fadingOut (0.2s) ──▶ [화면이 완전히 검은 순간] 리셋 ──▶ fadingIn (0.3s)
```

- 리셋(몽이 위치 · 발판 색 · 카메라)은 **단 한 콜백 지점**(`onFullyDark`)에서만 실행
- `isResetting` 플래그로 연출 중 입력·물리를 정지해 **중복 트리거를 차단**
- 모든 카메라 재배치는 **검은 화면 뒤**에서 일어나 사용자에게 보이지 않음

### 3. FCS (Flame Component System) 아키텍처

| 원칙 | 적용 |
| :--- | :--- |
| 🧩 **컴포넌트 격리** | 모든 게임 오브젝트를 독립 파일로 분리 (`player`, `platform`, `ground` …) |
| 🔢 **매직 넘버 격리** | 물리값·컬러 헥사코드를 전부 `constants.dart` 한 곳에서 관리 |
| ✂️ **로직 분리** | 입력(`onKeyEvent`) · 물리(`update`) · 렌더(`render`)를 명확히 구획 |
| 🎚️ **레벨 분리** | 레벨 디자인(`Stage1`)을 메인 게임 클래스에서 분리 |
| ✅ **무결성** | `flutter analyze` **경고 0건**의 깨끗한 코드 |

---

## 📂 프로젝트 폴더 구조

```
lib/
├── main.dart                  # 앱 진입점 — GameWidget으로 게임 로드
├── constants.dart             # 모든 상수 (물리값 · 파스텔 컬러 · 사이즈)
├── pong_pong_game.dart        # FlameGame 메인 — 조립 + 승리/패배 루프 조율
│
├── components/                # 게임 오브젝트 (FCS 단위 분리)
│   ├── player.dart            #  🐰 주인공 '몽이' — 입력 · 물리 · 충돌 · 렌더
│   ├── platform.dart          #  🟫 발판 — 흑백 ↔ 파스텔 전환 기믹
│   ├── ground.dart            #  🟩 시작 발판 — 몽이가 처음 디디는 출발점
│   ├── clear_banner.dart      #  🏆 스테이지 클리어 축하 배너 (팝업 연출)
│   └── fade_overlay.dart      #  ⬛ 페이드 인/아웃 상태 머신 오버레이
│
└── scenes/
    └── stage_1.dart           # 🗺️ 스테이지 1 레벨 디자인 (바닥 · 발판 배치)
```

| 파일 | 역할 |
| :--- | :--- |
| `main.dart` | Flutter 앱 시작점, `GameWidget<PongPongGame>` 로드 |
| `constants.dart` | 중력·속도·점프력 등 물리값과 파스텔 컬러 팔레트를 상수로 격리 |
| `pong_pong_game.dart` | `FlameGame` 상속, 레벨·플레이어·카메라 조립 및 게임 루프 조율 |
| `components/player.dart` | 키보드 입력, 중력·이동 물리, 발판/바닥/머리 충돌 판정, 캔버스 렌더 |
| `components/platform.dart` | `PlatformType`(monochrome/colored) 상태 관리 및 채색 기믹 |
| `components/ground.dart` | 화면 하단 중앙의 작은 시작 발판 |
| `components/clear_banner.dart` | "HAPPY MONG-I!" 텍스트 + `ScaleEffect` 팝업 등장 |
| `components/fade_overlay.dart` | `update` 기반 페이드 상태 머신 (낙사 연출) |
| `scenes/stage_1.dart` | 시작 발판 + 등반 가능한 지그재그 발판 10개 배치 |

---

## 🚀 실행 방법 (How to Run)

> 🎮 **그냥 플레이만 하려면** 설치가 필요 없습니다 — [여기서 바로 플레이](https://gojosuperman.github.io/pong_pong_sketch/)하세요.
> 아래는 **로컬에서 소스를 빌드·개발**하려는 경우의 안내이며, Flutter SDK(3.11 이상)가 필요합니다.

```bash
# 1) 저장소 클론
git clone https://github.com/GojoSuperman/pong_pong_sketch.git
cd pong_pong_sketch

# 2) 패키지 동기화
flutter pub get

# 3) 웹 브라우저(Chrome)에서 실행
flutter run -d chrome
```

추가 명령어:

| 명령어 | 설명 |
| :--- | :--- |
| `flutter pub get` | 의존성 패키지 동기화 |
| `flutter run -d chrome` | Chrome 브라우저에서 게임 실행 |
| `flutter analyze` | 정적 분석 (현재 경고 **0건**) |
| `flutter test` | 테스트 실행 |

---

## 🎨 디자인 톤 & 매너

- **비주얼:** 둥글둥글하고 귀여운 핸드드로잉 느낌 — 모든 오브젝트에 검은색 2dp 외곽선
- **컬러:** 소프트 파스텔톤 (배경 `#FAF8F5`, 핑크 `#FFB3C6` · 민트 `#B8E6D2` · 옐로우 `#FFE9A8`)
- **에셋:** MVP 단계에서는 이미지 없이 Flame `Canvas` 드로잉(`drawRRect`, `drawCircle`)으로 프로토타입 그래픽 생성

---

## 🧰 기술 스택

| 분류 | 사용 기술 |
| :--- | :--- |
| 언어 | Dart |
| 프레임워크 | Flutter |
| 게임 엔진 | Flame `1.37` |
| 플랫폼 | Web (Chrome 우선) |

---

<p align="center">
  <sub>🐰 Made with 몽이 & 파스텔 — a Flutter · Flame portfolio project.</sub>
</p>
