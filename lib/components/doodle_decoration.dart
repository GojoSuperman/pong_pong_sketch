import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../constants.dart';
import '../pong_pong_game.dart';

/// 배경 낙서 데코레이션의 모양 종류.
enum DoodleType {
  /// 연필로 슥슥 그린 별.
  star,

  /// 몽실한 낙서 구름.
  cloud,

  /// 위쪽을 가리키는 화살표 — 몽이에게 길을 알려주는 이정표.
  arrow,

  /// 제도용 직각 자(삼각자) — 스테이지 2 '도면의 방'.
  setSquare,

  /// 각도기 — 스테이지 2 '도면의 방'.
  protractor,

  /// 물방울 — 스테이지 3 '번지는 수채화 패드'.
  waterDrop,

  /// 붓 — 스테이지 3 '번지는 수채화 패드'.
  brush,

  /// 찢어진 종이 테두리 — 스테이지 4 '습격당한 낙서장'.
  tornPaper,

  /// X 표식 — 스테이지 4 '습격당한 낙서장'.
  xMark,

  /// 지우개 똥(가루 뭉치) — 스테이지 4 '습격당한 낙서장'.
  eraserCrumb,
}

/// 흑백 낙서 세상(퐁퐁 스케치 월드)의 분위기를 내는 배경 데코레이션.
///
/// 별도의 이미지 파일 없이 Flame의 Canvas 드로잉만으로, 연필로 대충 슥슥
/// 그린 듯한 외곽선(Stroke) 낙서를 그린다. 좌표에 약간의 비틀기(jitter)를
/// 주어 핸드드로잉의 불완전하고 귀여운 느낌을 살린다.
///
/// 살아 움직이도록 세 가지 연출이 더해진다:
/// - **둥실 애니메이션**: 모든 낙서가 정현파로 위아래로 부드럽게 떠다닌다.
/// - **구름 드리프트**: 구름은 좌우로도 천천히 흐르듯 왕복한다.
/// - **리액션**: 몽이가 가까이 오면 탱글하게 커졌다 돌아온다(가드로 중복 방지).
///
/// 몽이·발판보다 항상 뒤에 깔리도록 [priority]를 [kDoodlePriority](-1)로 둔다.
class DoodleDecoration extends PositionComponent
    with HasGameReference<PongPongGame> {
  DoodleDecoration({
    required this.type,
    required Vector2 position,
    double size = kDoodleSize,
    this.seed = 0,
  }) : super(
          position: position,
          size: Vector2.all(size),
          anchor: Anchor.center,
          priority: kDoodlePriority,
        );

  /// 그릴 낙서 모양.
  final DoodleType type;

  /// 핸드드로잉 비틀기·둥실 위상을 결정하는 난수 시드 — 같은 시드는 항상 같은 모양.
  final int seed;

  /// 외곽선 전용 Paint — 화려한 채우기 없이 선으로만 그린다.
  final Paint _strokePaint = Paint()
    ..color = kOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kOutlineWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// onLoad에서 단 한 번 만들어 캐시하는 낙서 경로.
  ///
  /// 매 프레임 재계산하면 jitter가 흔들려 보이므로 경로를 미리 굳혀 둔다.
  late final Path _doodlePath;

  /// 둥실 애니메이션의 기준 좌표 — 생성 시 위치를 onLoad에서 굳혀 둔다.
  late final Vector2 _basePosition;

  /// 낙서마다 둥실 위상을 어긋나게 해, 군집이 한 박자로 움직이지 않게 한다.
  late final double _floatPhase;

  /// 둥실 애니메이션 누적 시간 (초).
  double _elapsed = 0;

  /// 리액션 중복 실행 방지 가드 — true 동안 새 리액션을 발동하지 않는다.
  bool _isReacting = false;

  // ── 정화(Purification) 상태 ──

  /// 정화 면 채우기 전용 Paint — render마다 재생성하지 않도록 필드로 보관한다.
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  /// 타입별 파스텔 채움 색 — onLoad에서 한 번만 결정한다.
  late final Color _fillColor;

  /// 글로벌 정화가 발동됐는지 여부.
  bool _isPurifying = false;

  /// 정화 채움 진행도 (0 = 흑백 실선, 1 = 파스텔 면 완전 채움).
  double _purifyProgress = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final rng = Random(seed);
    _doodlePath = switch (type) {
      DoodleType.star => _buildStar(rng),
      DoodleType.cloud => _buildCloud(rng),
      DoodleType.arrow => _buildArrow(rng),
      DoodleType.setSquare => _buildSetSquare(rng),
      DoodleType.protractor => _buildProtractor(rng),
      DoodleType.waterDrop => _buildWaterDrop(rng),
      DoodleType.brush => _buildBrush(rng),
      DoodleType.tornPaper => _buildTornPaper(rng),
      DoodleType.xMark => _buildXMark(rng),
      DoodleType.eraserCrumb => _buildEraserCrumb(rng),
    };
    _basePosition = position.clone();
    _floatPhase = rng.nextDouble() * 2 * pi;

    // 타입별 파스텔 채움 색 — 별·각도기:옐로우, 구름·직각자:민트, 화살표:핑크.
    _fillColor = switch (type) {
      DoodleType.star => kPastelYellow,
      DoodleType.cloud => kPastelMint,
      DoodleType.arrow => kPastelPink,
      DoodleType.setSquare => kPastelMint,
      DoodleType.protractor => kPastelYellow,
      DoodleType.waterDrop => kPastelMint,
      DoodleType.brush => kPastelPink,
      DoodleType.tornPaper => kPastelYellow,
      DoodleType.xMark => kPastelPink,
      DoodleType.eraserCrumb => kPastelMint,
    };
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _applyFloat();
    _checkPlayerReaction();
    // 정화 발동 시 — 격자 만개 시간(kGridPurifyDuration)에 맞춰 채움이 0→1.
    if (_isPurifying && _purifyProgress < 1) {
      _purifyProgress =
          (_purifyProgress + dt / kGridPurifyDuration).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // 정화 진행 중이면 파스텔 면을 알파 0→1로 부드럽게 채운다(외곽선 아래).
    if (_purifyProgress > 0) {
      _fillPaint.color =
          _fillColor.withValues(alpha: _purifyProgress * kDoodleFillMaxAlpha);
      canvas.drawPath(_doodlePath, _fillPaint);
    }
    // 검은 외곽선은 정화 후에도 항상 유지된다.
    canvas.drawPath(_doodlePath, _strokePaint);
  }

  // ─────────────────────────────────────────────
  // 둥실 애니메이션 & 리액션
  // ─────────────────────────────────────────────

  /// 정현파로 위아래(+구름은 좌우) 둥실둥실 움직임을 매 프레임 적용한다.
  void _applyFloat() {
    final dy = sin(_elapsed * kDoodleFloatSpeed + _floatPhase) *
        kDoodleFloatAmplitude;
    // 구름만 좌우로도 천천히 흐르듯 왕복한다.
    final dx = type == DoodleType.cloud
        ? sin(_elapsed * kCloudDriftSpeed + _floatPhase) * kCloudDriftAmplitude
        : 0.0;
    position
      ..x = _basePosition.x + dx
      ..y = _basePosition.y + dy;
  }

  /// 몽이와의 거리를 재, 가까워지면 깜짝 리액션을 발동한다.
  ///
  /// [kDoodleReactDistance] 안으로 들어오면 한 번 반응하고 [_isReacting] 가드를
  /// 세운다. 몽이가 [kDoodleReactResetDistance] 밖으로 멀어지면 가드를 풀어,
  /// 다음 접근 때 다시 반응할 수 있게 한다(접근 1회당 리액션 1회).
  void _checkPlayerReaction() {
    final distance = position.distanceTo(game.player.position);

    if (distance > kDoodleReactResetDistance) {
      _isReacting = false; // 충분히 멀어짐 → 다음 접근에 다시 반응 가능.
      return;
    }

    // 리액션 거리 안 + 가드 해제 상태 + 낙사 리셋 연출 중 아님.
    if (distance <= kDoodleReactDistance && !_isReacting && !game.isResetting) {
      _isReacting = true; // 가드 — 멀어질 때까지 중복 발동 방지.
      _playReaction();
    }
  }

  /// 탱글하게 커졌다가 원래 크기로 돌아오는 '깜짝 놀람' 리액션.
  ///
  /// [ScaleEffect]는 완료되면 스스로 제거되므로 별도 정리가 필요 없다.
  void _playReaction() {
    add(ScaleEffect.to(
      Vector2.all(kDoodleReactScale),
      EffectController(
        duration: kDoodleReactDuration,
        reverseDuration: kDoodleReactDuration,
      ),
    ));
  }

  /// 정화도 100% 달성 시 호출 — 낙서 내부를 파스텔 색으로 채우기 시작한다.
  ///
  /// [update]에서 [_purifyProgress]가 격자 만개 시간에 맞춰 0→1로 차오르며,
  /// [render]가 채움 면의 알파를 서서히 올린다. 중복 호출은 무시한다.
  void purify() {
    if (_isPurifying) return;
    _isPurifying = true;
  }

  // ─────────────────────────────────────────────
  // 낙서 경로 빌더 (컴포넌트 로컬 좌표: 0..width, 0..height)
  // ─────────────────────────────────────────────

  /// 5각 별 — 바깥/안쪽 꼭짓점을 번갈아 이어 그린다.
  Path _buildStar(Random rng) {
    final path = Path();
    final cx = width / 2;
    final cy = height / 2;
    final outer = width * 0.46;
    final inner = outer * 0.42;
    const points = 5;

    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      // 맨 위(-90°)에서 시작해 시계방향으로 한 바퀴.
      final angle = -pi / 2 + i * pi / points;
      final x = cx + cos(angle) * radius + _wobble(rng);
      final y = cy + sin(angle) * radius + _wobble(rng);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  /// 몽실한 낙서 구름 — 크기가 다른 원 세 개를 만들되, [Path.combine]의
  /// 합집합(union)으로 합쳐 내부 겹침선 없이 바깥 테두리만 이어진 단일 패스로 그린다.
  Path _buildCloud(Random rng) {
    // (중심x 비율, 중심y 비율, 반지름 비율) — 가운데 봉우리가 가장 크다.
    const bumps = <(double, double, double)>[
      (0.32, 0.56, 0.22),
      (0.52, 0.44, 0.28),
      (0.70, 0.57, 0.20),
    ];

    Path? combined;
    for (final (bx, by, br) in bumps) {
      final oval = Path()
        ..addOval(Rect.fromCircle(
          center: Offset(
            width * bx + _wobble(rng),
            height * by + _wobble(rng),
          ),
          radius: width * br + _wobble(rng),
        ));
      // 첫 봉우리는 그대로, 이후 봉우리는 합집합으로 누적 병합.
      combined = combined == null
          ? oval
          : Path.combine(PathOperation.union, combined, oval);
    }
    return combined!;
  }

  /// 위쪽을 가리키는 화살표 — 세로 몸통 + 좌우 화살촉.
  Path _buildArrow(Random rng) {
    final path = Path();
    final cx = width / 2;
    final topY = height * 0.16;
    final bottomY = height * 0.86;
    final headSpread = width * 0.28;
    final headY = topY + height * 0.30;

    // 세로 몸통 (아래 → 위).
    path.moveTo(cx + _wobble(rng), bottomY + _wobble(rng));
    path.lineTo(cx + _wobble(rng), topY + _wobble(rng));

    // 화살촉 — 위 꼭짓점에서 좌우 아래로 뻗는 두 선.
    path.moveTo(cx - headSpread + _wobble(rng), headY + _wobble(rng));
    path.lineTo(cx + _wobble(rng), topY + _wobble(rng));
    path.lineTo(cx + headSpread + _wobble(rng), headY + _wobble(rng));
    return path;
  }

  /// 제도용 직각 자(삼각자) — 왼쪽 아래가 직각인 직각삼각형 외곽선.
  Path _buildSetSquare(Random rng) {
    final path = Path();
    final bl =
        Offset(width * 0.16 + _wobble(rng), height * 0.84 + _wobble(rng));
    final br =
        Offset(width * 0.86 + _wobble(rng), height * 0.84 + _wobble(rng));
    final tl =
        Offset(width * 0.16 + _wobble(rng), height * 0.18 + _wobble(rng));
    path.moveTo(bl.dx, bl.dy);
    path.lineTo(br.dx, br.dy);
    path.lineTo(tl.dx, tl.dy);
    path.close();
    return path;
  }

  /// 각도기 — 아래가 평평한 윗 반원(반원 호 + 지름선으로 닫은 단일 패스).
  Path _buildProtractor(Random rng) {
    final path = Path();
    final cx = width / 2;
    final baseY = height * 0.70;
    final radius = width * 0.42;
    final rect = Rect.fromCircle(center: Offset(cx, baseY), radius: radius);
    // 윗 반원 호 (왼쪽 → 위 → 오른쪽).
    path.addArc(rect, pi, pi);
    // 평평한 밑변(지름)으로 닫아 반원을 완성.
    path.lineTo(cx - radius + _wobble(rng), baseY + _wobble(rng));
    path.close();
    return path;
  }

  /// 물방울 — 위가 뾰족하고 아래가 둥근 눈물방울 형태.
  Path _buildWaterDrop(Random rng) {
    final path = Path();
    final cx = width / 2;
    final topY = height * 0.14;
    final bottomY = height * 0.86;
    final side = width * 0.40;
    final midY = height * 0.52;
    // 위 꼭짓점에서 시작.
    path.moveTo(cx + _wobble(rng), topY + _wobble(rng));
    // 오른쪽 — 꼭짓점 → 부풀며 → 둥근 바닥.
    path.cubicTo(cx + side, midY, cx + side, bottomY, cx, bottomY);
    // 왼쪽 — 둥근 바닥 → 부풀며 → 꼭짓점.
    path.cubicTo(
        cx - side, bottomY, cx - side, midY, cx + _wobble(rng), topY);
    path.close();
    return path;
  }

  /// 붓 — 비스듬한 손잡이 + 끝의 붓털 삼각형.
  Path _buildBrush(Random rng) {
    final path = Path();
    // 손잡이 — 좌상단에서 가운데로 내려오는 가는 선.
    path.moveTo(width * 0.22 + _wobble(rng), height * 0.18 + _wobble(rng));
    path.lineTo(width * 0.56 + _wobble(rng), height * 0.56 + _wobble(rng));
    // 붓털 — 손잡이 끝에서 좌우로 벌어지는 삼각형.
    path.moveTo(width * 0.56 + _wobble(rng), height * 0.56 + _wobble(rng));
    path.lineTo(width * 0.62 + _wobble(rng), height * 0.88 + _wobble(rng));
    path.lineTo(width * 0.88 + _wobble(rng), height * 0.70 + _wobble(rng));
    path.close();
    return path;
  }

  /// 찢어진 종이 테두리 — 둘레 8점을 크게 비틀어 들쭉날쭉한 사각형.
  Path _buildTornPaper(Random rng) {
    final path = Path();
    final m = width * 0.14;
    final left = m;
    final right = width - m;
    final top = m;
    final bottom = height - m;
    final midX = (left + right) / 2;
    final midY = (top + bottom) / 2;
    // 모서리 4 + 변 중앙 4 = 8점. 각 점을 크게 비틀어 찢긴 가장자리를 흉내.
    final points = <Offset>[
      Offset(left, top),
      Offset(midX, top),
      Offset(right, top),
      Offset(right, midY),
      Offset(right, bottom),
      Offset(midX, bottom),
      Offset(left, bottom),
      Offset(left, midY),
    ];
    for (var i = 0; i < points.length; i++) {
      final x = points[i].dx + _wobble(rng) * 2.4;
      final y = points[i].dy + _wobble(rng) * 2.4;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  /// X 표식 — 두 대각선이 교차하는 거친 X.
  Path _buildXMark(Random rng) {
    final path = Path();
    final m = width * 0.22;
    path.moveTo(m + _wobble(rng), m + _wobble(rng));
    path.lineTo(width - m + _wobble(rng), height - m + _wobble(rng));
    path.moveTo(width - m + _wobble(rng), m + _wobble(rng));
    path.lineTo(m + _wobble(rng), height - m + _wobble(rng));
    return path;
  }

  /// 지우개 똥 — 두 개의 큰 곡선으로 닫은 울퉁불퉁한 작은 콩알.
  Path _buildEraserCrumb(Random rng) {
    final path = Path();
    final cx = width / 2;
    final cy = height / 2;
    final r = width * 0.30;
    path.moveTo(cx + _wobble(rng), cy - r);
    path.cubicTo(
        cx + r * 1.5, cy - r * 0.7, cx + r * 1.1, cy + r * 1.2, cx, cy + r);
    path.cubicTo(
        cx - r * 1.4, cy + r * 0.9, cx - r * 1.5, cy - r, cx, cy - r);
    path.close();
    return path;
  }

  /// [-kDoodleJitter, kDoodleJitter] 범위의 작은 좌표 흔들림.
  double _wobble(Random rng) => (rng.nextDouble() - 0.5) * 2 * kDoodleJitter;
}
