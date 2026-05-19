import 'package:flame/components.dart';

import '../components/doodle_decoration.dart';
import '../components/ground.dart';
import '../components/platform.dart';
import '../components/sketchbook_background.dart';
import '../components/special_platforms.dart';
import '../constants.dart';

/// 스테이지 3 — '번지는 수채화 패드'.
///
/// 물리 법칙이 바뀌는 관문. 미끄러운 잉크 발판([SlipperyPlatform])과 트램펄린
/// 물감 발판([BouncyPlatform])을 섞어, 관성을 다스리고 초고공 점프로 먼 공중
/// 발판에 닿아야 오를 수 있게 한다. 배경 격자는 물에 번진 듯 투명한 워터블루.
class Stage3 extends Component {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final screen = Vector2(kGameWidth, kGameHeight);
    // 시작 베이스 땅은 화면 최하단 부근 — 종스크롤이라 위로 쌓아 올린다.
    const groundTop = kStageGroundTop;

    // 수채화 패드 격자 배경 — 물에 번진 듯 투명도 높은 워터블루.
    add(SketchbookBackground(
      position: Vector2(0, -screen.y),
      size: Vector2(screen.x, screen.y * 3),
      gridColor: kWatercolorGridColor,
    ));

    // 시작 발판 — 화면 하단 중앙.
    add(Ground(
      size: Vector2(kGroundWidth, kGroundHeight),
      position: Vector2((screen.x - kGroundWidth) / 2, groundTop),
    ));

    _spawnPlatforms(screen, groundTop);
    _spawnDoodles(screen, groundTop);
  }

  /// 일반·미끄럼·트램펄린 발판을 섞어 10칸 계단을 만든다.
  ///
  /// 트램펄린 발판([BouncyPlatform]) 바로 위 칸은 일반 점프로 닿지 못하게
  /// 멀리(150px) 띄워, 초고공 점프를 써야만 오를 수 있게 한다.
  void _spawnPlatforms(Vector2 screen, double groundTop) {
    const platformCount = 10;
    const platformWidth = 130.0;
    final centerX = screen.x / 2;

    // 칸별 종류 — n: 일반, s: 미끄럼, p: 트램펄린.
    const kinds = <String>['n', 's', 'p', 'n', 's', 'p', 'n', 's', 'p', 'n'];
    // 칸별 '아래에서 위로의 세로 간격' (px) — 트램펄린 위(3·6·9칸)는 멀게.
    const gaps = <double>[65, 65, 65, 150, 65, 65, 150, 65, 65, 150];
    // 칸별 가로 오프셋 (화면 중앙 기준) — 좌우 지그재그.
    // 트램펄린 칸과 그 위 칸은 가깝게 둬, 초고공 점프로 닿게 한다.
    const offsets = <double>[0, -95, 60, 30, 110, -55, -85, 75, 35, 70];

    var cumulative = 0.0;
    for (var i = 0; i < platformCount; i++) {
      cumulative += gaps[i];
      final topY = groundTop - cumulative;
      final leftX = (centerX + offsets[i] - platformWidth / 2)
          .clamp(0.0, screen.x - platformWidth)
          .toDouble();
      final pos = Vector2(leftX, topY);
      final pSize = Vector2(platformWidth, kPlatformHeight);
      final isGoal = i == platformCount - 1;

      add(switch (kinds[i]) {
        's' => SlipperyPlatform(
            position: pos, size: pSize, index: i, isGoal: isGoal),
        'p' => BouncyPlatform(
            position: pos, size: pSize, index: i, isGoal: isGoal),
        _ => Platform(position: pos, size: pSize, index: i, isGoal: isGoal),
      });
    }
  }

  /// 수채화 패드 분위기를 살리는 배경 낙서 — 물방울·붓을 흩뿌린다.
  void _spawnDoodles(Vector2 screen, double groundTop) {
    final centerX = screen.x / 2;
    // (모양, 가로 오프셋, 바닥에서 위로의 높이(px), 크기, 시드)
    const placements = <(DoodleType, double, double, double, int)>[
      (DoodleType.waterDrop, 150, 150, 56, 301),
      (DoodleType.brush, -155, 300, 70, 302),
      (DoodleType.waterDrop, 140, 470, 50, 303),
      (DoodleType.brush, -150, 620, 66, 304),
      (DoodleType.waterDrop, 160, 760, 54, 305),
      (DoodleType.brush, -140, 900, 64, 306),
    ];
    for (final (type, dx, up, size, seed) in placements) {
      final x = (centerX + dx).clamp(size / 2, screen.x - size / 2).toDouble();
      final y = groundTop - up;
      add(DoodleDecoration(
        type: type,
        position: Vector2(x, y),
        size: size,
        seed: seed,
      ));
    }
  }
}
