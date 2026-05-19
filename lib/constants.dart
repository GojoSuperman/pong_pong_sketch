import 'package:flutter/material.dart';

/// 게임 전역 상수 모음 (Pastel Casual Platformer)
///
/// 매직 넘버(물리 값, 컬러 헥사코드, 사이즈)를 한 곳에서 관리한다.
/// CLAUDE.md 규칙: 중력/속도 등 모든 매직 넘버는 이 파일에 상수로 선언한다.

// ─────────────────────────────────────────────
// 🎨 컬러 테마 (Pastel Casual)
// ─────────────────────────────────────────────

/// 핸드드로잉 외곽선 — 검은색 (모든 오브젝트 공통)
const Color kOutlineColor = Color(0xFF2B2B2B);

/// 외곽선 두께 — 검은색 2dp
const double kOutlineWidth = 2.0;

/// 게임 배경 — 소프트 화이트
const Color kBackgroundColor = Color(0xFFFAF8F5);

/// monochrome 발판 — 플레이어가 밟기 전 (흑백, 흰색 면 + 검은 외곽선)
const Color kMonochromeFill = Color(0xFFFFFFFF);

/// colored 발판 — 활성화 파스텔톤
const Color kPastelPink = Color(0xFFFFB3C6);
const Color kPastelMint = Color(0xFFB8E6D2);
const Color kPastelYellow = Color(0xFFFFE9A8);

/// 파스텔 팔레트 — 발판이 채워질 때 순환하여 사용
const List<Color> kPastelPalette = <Color>[
  kPastelPink,
  kPastelMint,
  kPastelYellow,
];

// ─────────────────────────────────────────────
// 🖼 게임 고정 해상도 (Fixed Resolution)
// ─────────────────────────────────────────────

/// 게임 고정 디자인 해상도 (px) — 세로형 모바일 9:16 비율.
///
/// 카메라가 이 해상도로 렌더하고, 브라우저 창이 더 크면 위·아래·좌우에
/// 레터박스(여백)를 넣어 레이아웃이 창 크기에 흔들리지 않게 한다.
const double kGameWidth = 600.0;
const double kGameHeight = 1066.0;

// ─────────────────────────────────────────────
// 🏃 몽이(Player) 물리 값
// ─────────────────────────────────────────────

/// 중력 가속도 (px/s²) — 양수, 아래 방향으로 가속
const double kGravity = 980.0;

/// 좌우 이동 속도 (px/s)
const double kMoveSpeed = 200.0;

/// 1단 점프 힘 — 위로 솟는 초기 속도 (px/s)
const double kJumpForce = 420.0;

/// 2단 점프 힘 — 부드러운 연출을 위해 1단보다 약간 약하게
const double kDoubleJumpForce = 360.0;

/// 최대 낙하 속도 (terminal velocity, px/s)
const double kMaxFallSpeed = 900.0;

/// 발판 밑머리 충돌 시 아래로 살짝 밀어내는 반동 속도 (px/s).
const double kHeadBumpRebound = 40.0;

// ─────────────────────────────────────────────
// 📐 오브젝트 사이즈
// ─────────────────────────────────────────────

/// 주인공 '몽이' 크기 (정사각 기준, px)
const double kPlayerSize = 40.0;

/// 발판 두께 (px)
const double kPlatformHeight = 24.0;

/// 시작 발판(Ground) 크기 (px) — 몽이가 처음 디디고 서는 작은 발판.
const double kGroundWidth = 200.0;
const double kGroundHeight = 64.0;

/// 시작 베이스 땅이 화면 맨 아래에서 떨어진 여백 (px) — 종스크롤 바닥 여백.
const double kStageBottomMargin = 28.0;

/// 시작 베이스 땅(Ground)의 윗면 y 좌표 — 화면 최하단 부근에 고정.
/// 모든 발판·몽이 스폰이 이 값을 바닥 원점으로 삼아 위로 차곡차곡 쌓인다.
const double kStageGroundTop = kGameHeight - kGroundHeight - kStageBottomMargin;

// ─────────────────────────────────────────────
// ✨ 점프 먼지 구름(Dust) 연출 값
// ─────────────────────────────────────────────

/// 점프 한 번에 피어오르는 먼지 입자 개수.
const int kDustParticleCount = 10;

/// 먼지 입자 하나의 수명 (초) — 피어올랐다 사라질 때까지.
const double kDustLifespan = 0.55;

/// 먼지 입자 시작 반경 (px) — 작게 시작.
const double kDustMinRadius = 3.0;

/// 먼지 입자 최대 반경 (px) — 몽실 커진 끝 크기.
const double kDustMaxRadius = 9.0;

/// 먼지가 위·바깥으로 퍼지는 기준 속도 (px/s).
const double kDustRiseSpeed = 90.0;

/// 먼지에 적용되는 중력 가속도 (px/s²) — 살짝 가라앉으며 사그라든다.
const double kDustGravity = 220.0;

/// 먼지 입자의 시작 불투명도 (0~1) — 이후 0으로 페이드아웃.
const double kDustStartAlpha = 0.85;

/// 먼지 전용 민트색 — 발판용 [kPastelMint](#B8E6D2)보다 한 톤 진하게.
const Color kDustMint = Color(0xFF93D6B8);

/// 먼지 전용 인디핑크색 — 발판용 [kPastelPink](#FFB3C6)보다 한 톤 진하게.
const Color kDustPink = Color(0xFFFF93AF);

// ─────────────────────────────────────────────
// ✏️ 배경 낙서 데코레이션(Doodle) 값
// ─────────────────────────────────────────────

/// 낙서 데코레이션 기본 크기 (정사각 기준, px).
const double kDoodleSize = 44.0;

/// 낙서 데코레이션 렌더 우선순위 — 음수라 몽이·발판보다 항상 뒤에 그려진다.
const int kDoodlePriority = -1;

/// 핸드드로잉 좌표 비틀기 폭 (px) — 연필로 슥슥 그린 듯한 불완전한 느낌.
const double kDoodleJitter = 2.5;

/// 낙서가 둥실둥실 떠다니는 상하 진폭 (px).
const double kDoodleFloatAmplitude = 7.0;

/// 낙서 상하 둥실 애니메이션 속도 (rad/s).
const double kDoodleFloatSpeed = 1.8;

/// 구름 낙서가 좌우로 흐르듯 왕복하는 진폭 (px).
const double kCloudDriftAmplitude = 35.0;

/// 구름 좌우 드리프트 속도 (rad/s) — 상하 둥실보다 느리게.
const double kCloudDriftSpeed = 0.8;

/// 몽이가 이 거리 안으로 들어오면 낙서가 깜짝 리액션한다 (px).
const double kDoodleReactDistance = 80.0;

/// 리액션 가드 해제 거리 (px) — 이 거리 밖으로 나가야 다시 리액션 가능.
/// 리액션 거리보다 넉넉히 크게 둬 경계에서 깜빡이는 현상을 막는다(히스테리시스).
const double kDoodleReactResetDistance = 115.0;

/// 리액션 시 낙서가 탱글하게 부풀어 오르는 배율.
const double kDoodleReactScale = 1.3;

/// 리액션 효과 한 방향(확대 또는 복귀) 지속 시간 (초).
const double kDoodleReactDuration = 0.15;

/// 정화 시 낙서 내부 파스텔 면이 채워지는 최대 불투명도 (0~1) — 부드러운 톤.
const double kDoodleFillMaxAlpha = 0.85;

// ─────────────────────────────────────────────
// 📒 스케치북 격자 배경(Grid) 값
// ─────────────────────────────────────────────

/// 배경 격자 컴포넌트 렌더 우선순위 — 낙서(-1)보다도 더 뒤.
const int kBackgroundPriority = -2;

/// 모눈종이 격자 간격 (px).
const double kGridSpacing = 28.0;

/// 격자 선 색 — 아주 연한 베이지/그레이.
const Color kSketchGridColor = Color(0xFFE8E5E0);

/// 격자 선 두께 (px).
const double kGridLineWidth = 1.0;

// ─────────────────────────────────────────────
// 🎭 딴짓(Idle Fidget) 값
// ─────────────────────────────────────────────

/// idle 상태가 끊김 없이 이 시간 이상 지속되면 무작위 딴짓을 발동한다 (초).
const double kFidgetTriggerDelay = 3.0;

// ── 동작 1: 눈 굴리기 ──

/// 눈이 한쪽 끝까지 치우치는 폭 (몽이 width 대비 비율).
const double kFidgetEyeRollMax = 0.11;

/// 한쪽 끝까지 가는 데 걸리는 시간 (초) — 좌·우 각각.
const double kFidgetEyeRollSidePhase = 0.5;

/// 정중앙으로 능청스럽게 복귀하는 시간 (초).
const double kFidgetEyeRollReturnPhase = 0.3;

// ── 동작 2: 파스텔 방귀 ──

/// 웅크리는 시간 (초).
const double kFidgetFartCrouchPhase = 0.15;

/// 뿅 튀어 오르는 시간 (초).
const double kFidgetFartPopPhase = 0.22;

/// 원위치로 가라앉는 시간 (초).
const double kFidgetFartSettlePhase = 0.28;

/// 웅크릴 때 아래로 내려가는 깊이 (px).
const double kFidgetFartCrouchDepth = 5.0;

/// 뿅 튈 때 위로 솟는 높이 (px).
const double kFidgetFartPopHeight = 9.0;

/// 방귀 먼지 입자 개수.
const int kFartPuffCount = 2;

/// 방귀 먼지 입자 수명 (초).
const double kFartPuffLifespan = 0.55;

/// 방귀 먼지 입자 시작 반경 (px).
const double kFartPuffMinRadius = 2.0;

/// 방귀 먼지 입자 최대 반경 (px).
const double kFartPuffMaxRadius = 6.0;

// ── 동작 3: 머리 긁기 ──

/// 손이 옆구리에서 머리 위로 나오는 시간 (초).
const double kFidgetScratchEmergePhase = 0.2;

/// 머리를 슥슥 긁는 시간 (초).
const double kFidgetScratchActivePhase = 0.8;

/// 손이 다시 옆구리로 숨는 시간 (초).
const double kFidgetScratchRetractPhase = 0.2;

/// 동글동글한 손의 반지름 (px).
const double kFidgetHandRadius = 7.0;

/// 머리를 긁을 때 손이 좌우로 슥슥 움직이는 폭 (px).
const double kFidgetScratchAmplitude = 6.0;

/// 머리를 긁는 횟수 (슥슥 좌우 왕복).
const int kFidgetScratchStrokes = 3;

// ─────────────────────────────────────────────
// 🌈 정화도 HUD(Purification HUD) 값
// ─────────────────────────────────────────────

/// HUD 전체 박스 크기 (px).
const double kHudWidth = 240.0;
const double kHudHeight = 58.0;

/// HUD가 화면 최상단에서 떨어진 거리 (px) — viewport 고정 기준.
const double kHudTopMargin = 14.0;

/// 정화도 게이지(프로그레스 바) 크기 (px).
const double kHudBarWidth = 166.0;
const double kHudBarHeight = 16.0;

/// 게이지 모서리 둥글기 반경 (px).
const double kHudBarRadius = 8.0;

/// 게이지 트랙(빈 바탕) 색 — 밟기 전 발판과 같은 흰 면.
const Color kHudTrackColor = kMonochromeFill;

/// 표시 정화도가 실제 값으로 수렴하는 속도 (1/s) — 게이지가 부드럽게 차오른다.
const double kHudFillLerpSpeed = 3.5;

/// '정화도' 라벨 글자 크기 (px).
const double kHudLabelFontSize = 12.0;

/// 퍼센트 숫자 글자 크기 (px).
const double kHudPercentFontSize = 16.0;

/// 단계별 축하 연출이 발동되는 정화도 임계값 (0~1, 오름차순).
const List<double> kPurificationMilestones = <double>[0.25, 0.5, 0.75, 1.0];

/// 마일스톤 달성 시 HUD가 탱글하게 부풀었다 돌아오는 배율.
const double kHudMilestonePulseScale = 1.18;

/// 마일스톤 펄스 한 방향(확대 또는 복귀) 지속 시간 (초).
const double kHudMilestonePulseDuration = 0.16;

// ─────────────────────────────────────────────
// 🎆 마일스톤 폭죽(Firework) & 글로벌 정화 값
// ─────────────────────────────────────────────

/// 폭죽 한 번에 터지는 입자 개수.
const int kFireworkParticleCount = 18;

/// 폭죽 입자 수명 (초).
const double kFireworkLifespan = 0.9;

/// 폭죽 입자 반경 (px).
const double kFireworkRadius = 5.0;

/// 폭죽 입자가 사방으로 퍼지는 최소/최대 속도 (px/s).
const double kFireworkMinSpeed = 80.0;
const double kFireworkMaxSpeed = 240.0;

/// 폭죽 입자에 작용하는 중력 (px/s²) — 포물선을 그리며 떨어진다.
const double kFireworkGravity = 180.0;

/// 클리어 배너 중심이 고정되는 세로 좌표 (px) — 상단 PURIFICATION HUD 아래,
/// 격자 두 줄(2 × kGridSpacing)만큼 더 내려 배치.
const double kClearBannerY = 174.0;

/// 클리어 배너 주변에서 폭죽이 터지는 지점의 배너 중심 기준 거리 (px).
const double kBannerFireworkSpread = 150.0;

/// 배너 폭죽 물결이 반복해 터지는 주기 (초) — 클리어 동안 계속 이어진다.
const double kBannerFireworkWaveGap = 0.45;

/// 정화도 100% 달성 시 격자가 무지개로 물드는 전환 시간 (초).
const double kGridPurifyDuration = 1.6;

/// 무지개 격자 색 순환 속도 (파스텔 3색 1회전/초) — 클수록 빠르게 흐른다.
const double kGridCycleSpeed = 0.18;

/// 격자 그라데이션에 동시에 보이는 무지개 띠(파스텔 3색 1세트)의 반복 수.
const double kGridRainbowRepeats = 3.0;

/// 무지개 그라데이션을 구성하는 색 정지점 개수 — 클수록 띠가 매끄럽다.
const int kGridGradientStops = 24;

// ─────────────────────────────────────────────
// 🎉 클리어 축하(Celebration) 값
// ─────────────────────────────────────────────

/// 클리어 축하 중 몽이가 제자리에서 퐁퐁 튀어오르는 점프 힘 (px/s).
/// 평소 점프([kJumpForce])보다 높게 — 기쁨에 차오른 점프.
const double kCelebrationJumpForce = 520.0;

/// 축하 점프 시 먼지 구름이 평소 점프보다 풍성해지는 배수.
const int kCelebrationDustMultiplier = 3;

/// 클리어 시 카메라 시점을 끌어내려 몽이를 화면 위쪽에 두는 비율 (화면 높이 대비).
/// 배너와 몽이 사이의 빈 가운데 공간을 줄여 준다.
const double kCelebrationCameraLift = 0.09;

// ─────────────────────────────────────────────
// 📐 스테이지 2: 정교한 도면의 방 (특수 발판)
// ─────────────────────────────────────────────

/// 움직이는 발판이 좌우로 왕복하는 전체 거리 (px) — 실제 진폭은 이 값의 절반.
const double kMovingPlatformRange = 120.0;

/// 움직이는 발판의 왕복 각속도 (rad/s) — 클수록 빠르게 오간다.
const double kMovingPlatformSpeed = 1.5;

/// 점선 발판이 켜져 있는(딛을 수 있는) 시간 (초).
const double kBlinkActiveDuration = 2.0;

/// 점선 발판이 꺼져 있는(딛지 못하는) 시간 (초).
const double kBlinkInactiveDuration = 1.5;

/// 점선 발판이 꺼졌을 때의 불투명도 (0~1).
const double kBlinkInactiveOpacity = 0.22;

/// 점선 한 칸(대시) 길이와 칸 사이 간격 (px).
const double kDashLength = 9.0;
const double kDashGap = 6.0;

/// 스테이지 2 청사진(제도 패드) 격자 선 색 — 은은한 도면 블루.
const Color kBlueprintGridColor = Color(0xFFC4D3E8);

// ─────────────────────────────────────────────
// 🎬 스테이지 전환 (Stage Transition)
// ─────────────────────────────────────────────

/// 클리어 후 축하 댄스를 보여주다 다음 스테이지로 넘어가기까지의 대기 시간 (초).
const double kStageClearHoldDuration = 3.0;

/// 전체 스테이지 개수 — 마지막 스테이지에서는 다음 전환을 하지 않는다.
const int kStageCount = 4;

// ─────────────────────────────────────────────
// 🎨 스테이지 3: 번지는 수채화 패드 (특수 물리 발판)
// ─────────────────────────────────────────────

/// 미끄러운 발판 — 밟기 전 파란 잉크 톤.
const Color kSlipperyInkColor = Color(0xFFB8D0E8);

/// 미끄러운 발판 위 좌우 속도가 목표값으로 수렴하는 속도 (1/s).
/// 작을수록 마찰이 약해 더 길게 쭈르륵 미끄러진다.
const double kSlipperyFriction = 5.0;

/// 트램펄린 발판 — 밟기 전 핑크 물감 톤.
const Color kBouncyPaintColor = Color(0xFFFFBED0);

/// 트램펄린 발판이 튕겨 올리는 초고공 점프 힘 (px/s).
/// 일반 점프([kJumpForce])의 약 2배 높이까지 솟는다.
const double kBouncyJumpForce = 600.0;

/// 스테이지 3 수채화 격자 선 색 — 물에 번진 듯 투명도 높은 워터블루.
const Color kWatercolorGridColor = Color(0x5586B8D8);

// ─────────────────────────────────────────────
// 🧹 스테이지 4: 습격당한 낙서장 (지우개 군단)
// ─────────────────────────────────────────────

/// 지우개 몬스터 크기 (px).
const double kEraserWidth = 34.0;
const double kEraserHeight = 30.0;

/// 지우개 순찰 속도 (px/s).
const double kEraserSpeed = 55.0;

/// 지우개 몸통 색 / 가운데 띠 색 — 투톤 지우개.
const Color kEraserBodyColor = Color(0xFFC9A0A0);
const Color kEraserBandColor = Color(0xFF9BB8C9);

/// 지우개가 밟혀 사라질 때 터지는 가루 입자 개수·수명·크기.
const int kEraserCrumbCount = 14;
const double kEraserCrumbLifespan = 0.6;
const double kEraserCrumbSize = 5.0;

/// 지우개를 밟았을 때 몽이가 통통 튀어오르는 반동 힘 (px/s).
const double kStompBounceForce = 300.0;

/// 지우개에 부딪혔을 때 hit(넉백) 상태가 유지되는 시간 (초) — 잠깐 무적.
const double kPlayerHitDuration = 0.45;

/// 넉백 속도 — 적 반대 가로 방향 / 위 방향 (px/s).
const double kKnockbackSpeedX = 190.0;
const double kKnockbackSpeedY = 300.0;
