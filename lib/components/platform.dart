import 'dart:ui';

import 'package:flame/components.dart';

import '../constants.dart';
import '../pong_pong_game.dart';

/// 발판(Platform)의 상태 — CLAUDE.md의 Core State 정의를 따른다.
enum PlatformType {
  /// 플레이어가 밟기 전 — 검은색 외곽선만, 안쪽은 흑백.
  monochrome,

  /// 플레이어가 밟은 후 — 파스텔톤 컬러로 활성화.
  colored,
}

/// 발판 컴포넌트.
///
/// 게임의 핵심 기믹 담당 — 몽이가 밟으면 흑백에서 파스텔톤으로 채워진다.
/// 각 발판은 고유 [index]를 가지며, 활성화 시 그 번호로 팔레트 색을 매칭한다.
class Platform extends PositionComponent
    with HasGameReference<PongPongGame> {
  Platform({
    required Vector2 position,
    required Vector2 size,
    required this.index,
    this.isGoal = false,
  }) : super(position: position, size: size);

  /// 컬러 팔레트(kPastelPalette) 순환용 고유 번호.
  final int index;

  /// 최종(스테이지 클리어) 발판 여부 — 맨 위 발판만 true.
  final bool isGoal;

  /// 발판의 현재 상태 (기본값: monochrome).
  PlatformType type = PlatformType.monochrome;

  /// 밟기 전(monochrome) 발판 면의 기본 색.
  /// 특수 발판이 잉크·물감 톤으로 바꿔 끼울 수 있도록 getter로 노출한다.
  Color get monochromeColor => kMonochromeFill;

  // ── 렌더용 Paint (매 프레임 재생성 방지를 위해 필드로 보관) ──
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  final Paint _outlinePaint = Paint()
    ..color = kOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kOutlineWidth;

  /// 플레이어가 발판을 밟았을 때 호출 — 파스텔톤으로 전환한다.
  ///
  /// 상태만 바꾸면 다음 [render] 프레임에서 새 색으로 그려진다.
  void changeToColored() {
    if (type == PlatformType.colored) return;
    type = PlatformType.colored;
  }

  /// 낙사 리셋 시 호출 — 발판을 다시 흑백 상태로 되돌린다.
  void resetToMonochrome() {
    type = PlatformType.monochrome;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 부드러운 라운드 사각형 — 핸드드로잉 캐주얼 톤.
    final body = RRect.fromRectAndRadius(
      Offset.zero & Size(width, height),
      const Radius.circular(10),
    );

    // [핵심] 상태에 따라 내부 채움색 결정.
    // colored → index로 파스텔 팔레트(핑크/민트/옐로우) 순환 매칭.
    _fillPaint.color = type == PlatformType.colored
        ? kPastelPalette[index % kPastelPalette.length]
        : monochromeColor;

    // 1) 안쪽 면 채우기 (monochrome / colored).
    canvas.drawRRect(body, _fillPaint);

    // 2) 검은 외곽선 2dp — 상태와 무관하게 항상 유지.
    canvas.drawRRect(body, _outlinePaint);
  }
}
