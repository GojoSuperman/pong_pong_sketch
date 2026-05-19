import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import '../constants.dart';

/// 스케치북 격자 배경 컴포넌트.
///
/// 퐁퐁 스케치 월드가 '공책 속 세상'이라는 세계관을 살리기 위해, 화면 전체에
/// 아주 연한 베이지/그레이 모눈종이 격자를 깐다. 별도의 이미지 없이 Flame의
/// Canvas 드로잉만 사용한다.
///
/// 몽이·발판·낙서보다 항상 가장 뒤에 그려지도록 [priority]를
/// [kBackgroundPriority](-2)로 둔다.
///
/// 정화도 100% 달성 시 [purify]가 호출되면, 흑백에 가깝던 격자 선이
/// 파스텔 3색(핑크·민트·옐로우)이 매 프레임 흐르는 '살아 움직이는 무지개'로
/// 물들어 간다.
class SketchbookBackground extends PositionComponent {
  SketchbookBackground({
    required Vector2 position,
    required Vector2 size,
    Color gridColor = kSketchGridColor,
  })  : _baseGridColor = gridColor,
        super(position: position, size: size, priority: kBackgroundPriority);

  /// 격자 선의 기본 색 — 스테이지마다 다르게 줄 수 있다
  /// (스케치북 그레이 / 청사진 블루). 정화 시 이 색에서 무지개로 보간된다.
  final Color _baseGridColor;

  /// 무지개 색 순환에 쓰는 핵심 파스텔 3색 (핑크 → 민트 → 옐로우).
  static const List<Color> _cycleColors = <Color>[
    kPastelPink,
    kPastelMint,
    kPastelYellow,
  ];

  /// 격자 선 전용 Paint — 평소엔 [_baseGridColor], 정화 후엔 무지개 shader.
  /// 색은 onLoad에서 [_baseGridColor]로 설정한다.
  final Paint _gridPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = kGridLineWidth;

  /// onLoad에서 한 번만 만들어 캐시하는 격자 경로 — 매 프레임 재계산 방지.
  late final Path _gridPath;

  /// 글로벌 정화가 시작됐는지 여부.
  bool _isPurifying = false;

  /// 무지개 만개 진행도 (0 = 흑백 격자, 1 = 완전한 파스텔 무지개).
  double _purifyProgress = 0;

  /// 무지개 색 순환 위상 — 매 프레임 증가해 무지개 띠가 흐르게 한다.
  double _cyclePhase = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _gridPaint.color = _baseGridColor;

    final path = Path();
    // 세로선 — 왼쪽에서 오른쪽으로 일정 간격.
    for (var x = 0.0; x <= width; x += kGridSpacing) {
      path.moveTo(x, 0);
      path.lineTo(x, height);
    }
    // 가로선 — 위에서 아래로 일정 간격.
    for (var y = 0.0; y <= height; y += kGridSpacing) {
      path.moveTo(0, y);
      path.lineTo(width, y);
    }
    _gridPath = path;
  }

  /// 정화도 100% 달성 시 호출 — 격자의 무지개 정화 연출을 시작한다.
  ///
  /// 한 번 시작되면 [update]에서 만개 진행도가 0→1로 차오르고, 그 뒤로도
  /// 색 순환은 계속된다. 중복 호출은 무시한다.
  void purify() {
    if (_isPurifying) return;
    _isPurifying = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isPurifying) return;

    // 1) 흑백 → 무지개 만개 진행도 (한 번만 0→1로 차오른다).
    if (_purifyProgress < 1) {
      _purifyProgress =
          (_purifyProgress + dt / kGridPurifyDuration).clamp(0.0, 1.0);
    }
    // 2) 색 순환 위상 — 계속 전진해 무지개 띠가 흐른다.
    _cyclePhase += dt * kGridCycleSpeed;

    _rebuildGridShader();
  }

  /// 파스텔 3색을 순환 보간해 위상 [t] 지점의 무지개 색을 구한다.
  Color _rainbowColor(double t) {
    final scaled = (t % 1.0) * _cycleColors.length; // 0.0 ~ 3.0
    final index = scaled.floor() % _cycleColors.length;
    final next = (index + 1) % _cycleColors.length;
    return Color.lerp(
      _cycleColors[index],
      _cycleColors[next],
      scaled - scaled.floorToDouble(),
    )!;
  }

  /// 현재 진행도·위상에 맞춰 격자 그라데이션 shader를 다시 만든다.
  ///
  /// 각 색 정지점을 기본 격자색([_baseGridColor])에서 흐르는 무지개색으로
  /// [_purifyProgress]만큼 보간한다 — 진행도 0이면 기본색과 똑같고,
  /// 1이면 좌상단→우하단으로 흐르는 완전한 파스텔 무지개가 된다.
  void _rebuildGridShader() {
    final colors = <Color>[];
    for (var i = 0; i <= kGridGradientStops; i++) {
      final stopT = i / kGridGradientStops;
      // 위치 + 순환 위상 → 흐르는 무지개. repeats 만큼 띠가 보인다.
      final rainbow = _rainbowColor(stopT * kGridRainbowRepeats + _cyclePhase);
      colors.add(Color.lerp(_baseGridColor, rainbow, _purifyProgress)!);
    }
    _gridPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ).createShader(Rect.fromLTWH(0, 0, width, height));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawPath(_gridPath, _gridPaint);
  }
}
