import 'package:flame/components.dart';

import '../components/doodle_decoration.dart';
import '../components/eraser_enemy.dart';
import '../components/ground.dart';
import '../components/platform.dart';
import '../components/sketchbook_background.dart';
import '../components/special_platforms.dart';
import '../constants.dart';

/// 스테이지 4 — '습격당한 낙서장'. 최종 스테이지.
///
/// 움직이는 발판·트램펄린 발판에 더해, 발판을 순찰하며 정화를 지우는 적
/// [EraserEnemy]가 등장한다. 지우개를 밟아 처치하지 않으면 그 발판의 정화가
/// 계속 깎이는 긴장감이 핵심.
class Stage4 extends Component {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final screen = Vector2(kGameWidth, kGameHeight);
    // 시작 베이스 땅은 화면 최하단 부근 — 종스크롤이라 위로 쌓아 올린다.
    const groundTop = kStageGroundTop;

    // 습격당한 낙서장 — 스케치북 격자 배경.
    add(SketchbookBackground(
      position: Vector2(0, -screen.y),
      size: Vector2(screen.x, screen.y * 3),
    ));

    // 시작 발판 — 화면 하단 중앙.
    add(Ground(
      size: Vector2(kGroundWidth, kGroundHeight),
      position: Vector2((screen.x - kGroundWidth) / 2, groundTop),
    ));

    _spawnPlatforms(screen, groundTop);
    _spawnDoodles(screen, groundTop);
  }

  /// 일반·움직이는·트램펄린 발판을 섞고, 일부 발판엔 지우개 적을 순찰시킨다.
  ///
  /// 트램펄린 발판([BouncyPlatform]) 위 칸은 멀리(150px) 띄워 초고공 점프를
  /// 쓰게 하고, 'e' 칸에는 발판을 지우는 [EraserEnemy]를 올려 난이도를 높인다.
  void _spawnPlatforms(Vector2 screen, double groundTop) {
    const platformCount = 10;
    const platformWidth = 130.0;
    final centerX = screen.x / 2;

    // 칸별 종류 — n: 일반, e: 일반+지우개, m: 움직이는, p: 트램펄린.
    const kinds = <String>['n', 'e', 'm', 'p', 'n', 'e', 'm', 'p', 'e', 'n'];
    // 칸별 세로 간격 (px) — 트램펄린 위(4·8칸)는 멀게.
    const gaps = <double>[65, 65, 65, 65, 145, 65, 65, 65, 145, 65];
    // 칸별 가로 오프셋 (화면 중앙 기준).
    const offsets = <double>[0, -100, 70, 40, 115, -60, -95, 80, 45, 70];

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

      final platform = switch (kinds[i]) {
        'm' => MovingPlatform(
            position: pos, size: pSize, index: i, isGoal: isGoal),
        'p' => BouncyPlatform(
            position: pos, size: pSize, index: i, isGoal: isGoal),
        _ => Platform(position: pos, size: pSize, index: i, isGoal: isGoal),
      };
      add(platform);

      // 'e' 칸 — 그 발판 위에 순찰하는 지우개 적을 배치한다.
      if (kinds[i] == 'e') {
        add(EraserEnemy(platform: platform));
      }
    }
  }

  /// 습격당한 낙서장 분위기 — 찢어진 종이·X 표식·지우개 똥 낙서를 흩뿌린다.
  void _spawnDoodles(Vector2 screen, double groundTop) {
    final centerX = screen.x / 2;
    // (모양, 가로 오프셋, 바닥에서 위로의 높이(px), 크기, 시드)
    const placements = <(DoodleType, double, double, double, int)>[
      (DoodleType.tornPaper, 150, 160, 64, 401),
      (DoodleType.xMark, -150, 310, 48, 402),
      (DoodleType.eraserCrumb, 140, 450, 44, 403),
      (DoodleType.xMark, 160, 600, 46, 404),
      (DoodleType.tornPaper, -145, 740, 60, 405),
      (DoodleType.eraserCrumb, -150, 880, 42, 406),
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
