\# 프로젝트 가이드라인: 파스텔 캐주얼 플랫포머 (Flame)



이 프로젝트는 Flutter와 Flame 프레임워크를 사용하여 개발하는 포트폴리오용 토이 플랫포머 게임입니다. 모든 개발은 MVP(최소 기능 제품) 구현을 목표로 합니다.



\## 🛠 필수 명령어 (Build \& Run)

\- 프로젝트 실행: `flutter run -d chrome` (웹 브라우저 테스트 우선)

\- 패키지 동기화: `flutter pub get`

\- 테스트 실행: `flutter test`



\## 🏗 아키텍처 및 코드 스타일 규칙

1\. \*\*FCS (Flame Component System) 준수\*\*

&#x20;  - 모든 오브젝트(플레이어, 발판 등)는 Flame의 Component를 상속받아 독립된 파일로 분리합니다.

&#x20;  - 가능하면 `HasGameReference`를 믹스인하여 메인 게임 클래스에 접근하세요.



2\. \*\*상태 관리 및 컴포넌트 격리\*\*

&#x20;  - 플레이어의 상태(이동, 점프 등)는 이넘(enum) 클래스로 관리하며, 입력(Input) 로직과 물리(Physics) 로직을 명확히 분리합니다.

&#x20;  - 매직 넘버(중력 값, 속도 등)는 `constants.dart` 파일에 상수로 선언하여 관리합니다.



\## 🎨 아트 및 게임 디자인 제약 조건 (Pastel Casual)

\- \*\*비주얼 톤앤매너:\*\* '몽이'의 모험을 다룬 둥글둥글하고 귀여운 핸드드로잉 느낌의 에셋을 사용합니다. UI 및 배경은 소프트 파스텔톤을 유지합니다.

\- \*\*기믹:\*\* 플레이어가 밟은 흑백 발판이 파스텔톤으로 채워지는 시각적 피드백과 부드러운 2단 점프를 핵심으로 합니다.



\## 📂 권장 폴더 구조 (Directory Structure)

모든 새로운 파일은 기능에 따라 반드시 아래 구조를 지켜서 생성해야 합니다.

\- `lib/constants.dart`: 게임의 모든 상수 (물리 값, 컬러 헥사코드)

\- `lib/main.dart`: 플러터 앱 시작점 및 게임 위젯 로드

\- `lib/pong\_pong\_game.dart`: FlameGame 메인 클래스 (게임 루프 및 글로벌 관리)

\- `lib/components/`: 모든 게임 오브젝트 독립 파일

&#x20; - `lib/components/player.dart`: 주인공 '몽이' 컴포넌트

&#x20; - `lib/components/platform.dart`: 발판 컴포넌트 (흑백/컬러 전환 로직 포함)

&#x20; - `lib/components/ground.dart`: 바닥 및 벽 컴포넌트

\- `lib/scenes/`: 스테이지 및 맵 관리

&#x20; - `lib/scenes/stage\_1.dart`: 1스테이지 배치 및 레벨 디자인 코드



\## 🎭 핵심 데이터 구조 및 상태 (Core State \& Enums)

1\. \*\*PlayerState (몽이의 상태):\*\*

&#x20;  - `idle`: 가만히 서 있을 때

&#x20;  - `running`: 좌우로 이동 중일 때

&#x20;  - `jumping`: 첫 번째 점프 상승 중일 때

&#x20;  - `doubleJumping`: 2단 점프 상승 중일 때

&#x20;  - `falling`: 공중에서 낙하 중일 때

&#x20;  - `hit`: 함정에 부딪혔을 때



2\. \*\*PlatformType (발판의 상태):\*\*

&#x20;  - `monochrome`: 플레이어가 밟기 전 (검은색 선만 존재)

&#x20;  - `colored`: 플레이어가 밟은 후 (파스텔톤 컬러 활성화)



\## 🎨 에셋 프리셋 규칙 (Asset Workflow)

\- MVP 단계에서는 실제 이미지(.png)를 불러오지 않고, Flame의 `Canvas` 그리기 기능(`drawRect`, `drawCircle`)을 활용해 임시 그래픽(프로토타입)을 생성합니다.

\- 외곽선은 검은색 2dp 두께로 그려 핸드드로잉 느낌을 흉내 냅니다.

