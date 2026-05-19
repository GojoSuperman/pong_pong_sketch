import 'dart:math';
import 'dart:ui';

import '../constants.dart';
import 'platform.dart';

/// 좌우로 부드럽게 왕복 이동하는 발판 — 스테이지 2 '움직이는 제도용 자'.
///
/// 기본 [Platform]을 상속해 색 전환·클리어 판정은 그대로 쓰고, [update]에서
/// 정현파로 x를 왕복시킨다. 한 프레임에 움직인 거리는 [lastDx]로 노출해,
/// 발판 위에 선 몽이가 같은 만큼 함께 실려 가도록 한다([Player]가 참조).
class MovingPlatform extends Platform {
  MovingPlatform({
    required super.position,
    required super.size,
    required super.index,
    super.isGoal,
    this.range = kMovingPlatformRange,
  }) : _originX = position.x;

  /// 좌우로 왕복하는 전체 거리 (px) — 실제 진폭은 이 값의 절반.
  final double range;

  /// 왕복의 기준 중심 x — 생성 시점의 x.
  final double _originX;

  /// 정현파 위상 (rad).
  double _phase = 0;

  /// 직전 프레임에 발판이 움직인 x 변위 — 몽이를 함께 실어 나르는 데 쓴다.
  double lastDx = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * kMovingPlatformSpeed;
    // 진폭 = 전체 거리의 절반. sin으로 좌우를 부드럽게 왕복한다.
    final newX = _originX + sin(_phase) * (range / 2);
    lastDx = newX - position.x;
    position.x = newX;
  }
}

/// 점선(Dashed)으로 그려지며 주기적으로 켜졌다 꺼지는 발판 — 스테이지 2.
///
/// 켜진 동안만 몽이가 딛을 수 있고, 꺼지면 흐려지며 충돌이 비활성된다.
/// [Player]의 착지·머리 충돌 판정이 [isActive]를 보고 꺼진 발판은 건너뛴다.
class BlinkingPlatform extends Platform {
  BlinkingPlatform({
    required super.position,
    required super.size,
    required super.index,
    super.isGoal,
  });

  /// 깜빡임 누적 시간 (초).
  double _timer = 0;

  /// 현재 딛을 수 있는 상태인지 — [Player]가 충돌 판정에서 참조한다.
  bool isActive = true;

  /// 점선 외곽선 전용 Paint (매 프레임 재생성 방지).
  final Paint _dashPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = kOutlineWidth
    ..strokeCap = StrokeCap.round;

  /// 안쪽 면 전용 Paint (매 프레임 재생성 방지).
  final Paint _facePaint = Paint()..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    // 활성(kBlinkActiveDuration) → 비활성(kBlinkInactiveDuration) 주기 반복.
    const cycle = kBlinkActiveDuration + kBlinkInactiveDuration;
    isActive = (_timer % cycle) < kBlinkActiveDuration;
  }

  @override
  void render(Canvas canvas) {
    // 점선 스타일이라 Platform.render(꽉 찬 사각형)는 쓰지 않는다.
    // 꺼졌을 땐 전체를 흐리게 그려 '딛을 수 없음'을 알린다.
    final opacity = isActive ? 1.0 : kBlinkInactiveOpacity;
    final rect = Offset.zero & Size(width, height);

    // 안쪽 면 — 밟기 전 흰 면 / 밟은 후 파스텔 (점선 발판도 색 전환을 따른다).
    final faceColor = type == PlatformType.colored
        ? kPastelPalette[index % kPastelPalette.length]
        : kMonochromeFill;
    _facePaint.color = faceColor.withValues(alpha: opacity);
    canvas.drawRect(rect, _facePaint);

    // 점선 외곽선 — 네 변을 짧은 대시로 끊어 그린다.
    _dashPaint.color = kOutlineColor.withValues(alpha: opacity);
    _drawDashedLine(canvas, rect.topLeft, rect.topRight);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft);
  }

  /// 두 점을 잇는 직선을 짧은 대시 + 간격으로 끊어 그린다 (점선 효과).
  void _drawDashedLine(Canvas canvas, Offset from, Offset to) {
    final total = (to - from).distance;
    if (total <= 0) return;
    final dir = (to - from) / total; // 단위 방향 벡터.
    var drawn = 0.0;
    while (drawn < total) {
      final start = from + dir * drawn;
      final end = from + dir * min(drawn + kDashLength, total);
      canvas.drawLine(start, end, _dashPaint);
      drawn += kDashLength + kDashGap;
    }
  }
}

/// 파란 잉크 톤의 미끄러운 발판 — 스테이지 3 '번지는 수채화 패드'.
///
/// 시각적으로만(파란 톤) 다르고, 미끄러짐 물리는 [Player]가 이 타입을 보고
/// 마찰을 약하게 처리한다 — 입력을 멈춰도 즉시 서지 못하고 쭈르륵 미끄러진다.
class SlipperyPlatform extends Platform {
  SlipperyPlatform({
    required super.position,
    required super.size,
    required super.index,
    super.isGoal,
  });

  @override
  Color get monochromeColor => kSlipperyInkColor;
}

/// 핑크 물감 톤의 트램펄린 발판 — 스테이지 3 '번지는 수채화 패드'.
///
/// 시각적으로만(핑크 톤) 다르고, 닿는 순간 [Player]가 이 타입을 보고 속도를
/// 강하게 위로 튕겨 일반 점프의 약 2배 높이로 초고공 점프시킨다.
class BouncyPlatform extends Platform {
  BouncyPlatform({
    required super.position,
    required super.size,
    required super.index,
    super.isGoal,
  });

  @override
  Color get monochromeColor => kBouncyPaintColor;
}
