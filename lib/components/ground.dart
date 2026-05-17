import 'dart:ui';

import 'package:flame/components.dart';

import '../constants.dart';

/// 시작 발판(Ground) 컴포넌트.
///
/// 화면 하단 중앙에 놓이는 작은 발판으로, 몽이가 처음 안전하게 디디고 서는
/// 출발점이다. 더 이상 화면 전폭 바닥이 아니므로, 이 발판을 벗어나면
/// 낭떠러지로 떨어진다.
///
/// 위치·크기는 Stage1에서 주입한다.
class Ground extends PositionComponent {
  Ground({required Vector2 size, required Vector2 position})
      : super(size: size, position: position);

  // ── 렌더용 Paint (매 프레임 재생성 방지를 위해 필드로 보관) ──
  final Paint _fillPaint = Paint()
    ..color = kMonochromeFill
    ..style = PaintingStyle.fill;

  final Paint _outlinePaint = Paint()
    ..color = kOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kOutlineWidth;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 네 모서리가 둥근 라운드 사각형 — 공중 발판과 동일한 핸드드로잉 톤.
    final body = RRect.fromRectAndRadius(
      Offset.zero & Size(width, height),
      const Radius.circular(10),
    );

    // 1) 안쪽 면 채우기 — 밟기 전 흑백 톤(흰 면).
    canvas.drawRRect(body, _fillPaint);

    // 2) 검은 외곽선 2dp — 핸드드로잉 흉내.
    canvas.drawRRect(body, _outlinePaint);
  }
}
