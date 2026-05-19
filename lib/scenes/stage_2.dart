import 'package:flame/components.dart';

import '../components/doodle_decoration.dart';
import '../components/ground.dart';
import '../components/platform.dart';
import '../components/sketchbook_background.dart';
import '../components/special_platforms.dart';
import '../constants.dart';

/// 스테이지 2 — '정교한 도면의 방'.
///
/// 제도용 자와 점선이 테마. 움직이는 자([MovingPlatform])와 점선 발판
/// ([BlinkingPlatform])을 일반 발판 사이사이에 섞어, 타이밍을 맞춰 점프하는
/// 리듬감을 만든다. 배경은 은은한 청사진 블루 격자.
///
/// [Stage1]과 좌표 체계·구조는 같지만 발판 구성과 배경 색이 다르다.
class Stage2 extends Component {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 고정 해상도 기준 레이아웃 — Stage1과 동일한 좌표 체계.
    final screen = Vector2(kGameWidth, kGameHeight);
    // 시작 베이스 땅은 화면 최하단 부근 — 종스크롤이라 위로 쌓아 올린다.
    const groundTop = kStageGroundTop;

    // 청사진(제도 패드) 격자 배경 — 은은한 도면 블루.
    add(SketchbookBackground(
      position: Vector2(0, -screen.y),
      size: Vector2(screen.x, screen.y * 3),
      gridColor: kBlueprintGridColor,
    ));

    // 시작 발판 — 화면 하단 중앙.
    add(Ground(
      size: Vector2(kGroundWidth, kGroundHeight),
      position: Vector2((screen.x - kGroundWidth) / 2, groundTop),
    ));

    _spawnPlatforms(screen, groundTop);
    _spawnDoodles(screen, groundTop);
  }

  /// 일반·움직이는·점선 발판을 섞어 10칸 계단을 만든다.
  ///
  /// 칸마다 종류를 달리해, 움직이는 자에 올라타고 점선 발판이 켜지는 타이밍에
  /// 맞춰 점프하는 리듬을 부여한다. 가장 위(목표) 발판은 안정적인 일반 발판.
  void _spawnPlatforms(Vector2 screen, double groundTop) {
    const platformCount = 10;
    const platformWidth = 130.0;
    const topMargin = 70.0;

    final climbableHeight = groundTop - topMargin;
    final stepY =
        (climbableHeight / (platformCount + 1)).clamp(0.0, 78.0).toDouble();
    final centerX = screen.x / 2;

    // 칸별 가로 오프셋 (화면 중앙 기준).
    const offsets = <double>[0, -90, 60, -120, 30, 120, -60, 100, -40, 0];
    // 칸별 발판 종류 — n: 일반, m: 움직이는 자, b: 점선 발판.
    const kinds = <String>['n', 'm', 'b', 'm', 'b', 'm', 'b', 'm', 'b', 'n'];

    for (var i = 0; i < platformCount; i++) {
      final topY = groundTop - stepY * (i + 1);
      final leftX = (centerX + offsets[i] - platformWidth / 2)
          .clamp(0.0, screen.x - platformWidth)
          .toDouble();
      final pos = Vector2(leftX, topY);
      final pSize = Vector2(platformWidth, kPlatformHeight);
      final isGoal = i == platformCount - 1;

      add(switch (kinds[i]) {
        'm' => MovingPlatform(
            position: pos, size: pSize, index: i, isGoal: isGoal),
        'b' => BlinkingPlatform(
            position: pos, size: pSize, index: i, isGoal: isGoal),
        _ => Platform(position: pos, size: pSize, index: i, isGoal: isGoal),
      });
    }
  }

  /// 도면의 방 분위기를 살리는 배경 낙서 — 직각 자·각도기를 흩뿌린다.
  void _spawnDoodles(Vector2 screen, double groundTop) {
    const platformCount = 10;
    const topMargin = 70.0;
    final climbableHeight = groundTop - topMargin;
    final stepY =
        (climbableHeight / (platformCount + 1)).clamp(0.0, 78.0).toDouble();
    final centerX = screen.x / 2;

    // (모양, 가로 오프셋, 칸 번호(소수=반 칸), 크기, 시드)
    const placements = <(DoodleType, double, double, double, int)>[
      (DoodleType.setSquare, 150, 1.6, 64, 201),
      (DoodleType.protractor, -150, 2.7, 70, 202),
      (DoodleType.setSquare, 140, 3.6, 56, 203),
      (DoodleType.arrow, -135, 4.6, 50, 204),
      (DoodleType.protractor, 160, 5.6, 66, 205),
      (DoodleType.setSquare, -150, 6.7, 58, 206),
      (DoodleType.protractor, 130, 7.6, 62, 207),
      (DoodleType.setSquare, -130, 8.7, 54, 208),
    ];

    for (final (type, dx, step, size, seed) in placements) {
      final x = (centerX + dx).clamp(size / 2, screen.x - size / 2).toDouble();
      final y = groundTop - stepY * step;
      add(DoodleDecoration(
        type: type,
        position: Vector2(x, y),
        size: size,
        seed: seed,
      ));
    }
  }
}
