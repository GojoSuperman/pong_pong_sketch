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
