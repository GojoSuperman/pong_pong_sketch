import 'package:flame/components.dart';

import '../components/doodle_decoration.dart';
import '../components/ground.dart';
import '../components/platform.dart';
import '../components/sketchbook_background.dart';
import '../constants.dart';
import '../pong_pong_game.dart';

/// 스테이지 1 — 레벨 디자인(바닥·발판 배치)을 담당하는 컨테이너 컴포넌트.
///
/// 메인 게임([PongPongGame])에서 레벨 구성 코드를 분리해 한곳에 모은다.
/// 자기 자신은 좌표 없는 [Component]이며, 자식(Ground·Platform)이 월드 좌표를 가진다.
class Stage1 extends Component with HasGameReference<PongPongGame> {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 고정 해상도 기준으로 레벨을 배치 — 창 크기와 무관하게 일정한 레이아웃.
    final screen = Vector2(kGameWidth, kGameHeight);
    // 시작 베이스 땅은 화면 최하단 부근 — 종스크롤이라 위로 쌓아 올린다.
    const groundTop = kStageGroundTop;

    // 스케치북 격자 배경 — 카메라가 위로 따라 올라가도 항상 화면을 덮도록
    // 화면 높이의 3배 크기로 넉넉히 깐다. priority -2라 가장 뒤에 그려진다.
    add(SketchbookBackground(
      position: Vector2(0, -screen.y),
      size: Vector2(screen.x, screen.y * 3),
    ));

    // 시작 발판(Ground) — 화면 하단 중앙에 작은 발판 하나로 배치.
    // 화면 전폭이 아니므로 이 발판을 벗어나면 낭떠러지로 떨어진다.
    add(Ground(
      size: Vector2(kGroundWidth, kGroundHeight),
      position: Vector2((screen.x - kGroundWidth) / 2, groundTop),
    ));

    // 점프로 한 칸씩 오를 수 있는 지그재그 발판 10개.
    _spawnClimbablePlatforms(screen, groundTop);

    // 발판 뒤편(흑백 낙서 세상)을 채우는 배경 데코레이션.
    _spawnDoodles(screen, groundTop);
  }

  /// 점프로 한 칸씩 오를 수 있는 지그재그 발판 10개를 배치한다.
  ///
  /// 화면 비율이 아닌 '절대 픽셀'로 칸 높이를 정해, 한 번 점프(약 90px) 안에
  /// 윗 발판에 닿도록 보장한다.
  void _spawnClimbablePlatforms(Vector2 screen, double groundTop) {
    const platformCount = 10;
    const platformWidth = 130.0;
    const topMargin = 70.0;

    final climbableHeight = groundTop - topMargin;
    // 한 칸 높이 — 1단 점프 사거리(약 90px) 안쪽인 78px로 상한 제한.
    final stepY =
        (climbableHeight / (platformCount + 1)).clamp(0.0, 78.0).toDouble();

    // 화면 중앙 기준 가로 오프셋 — 좌우로 굽이치는 지그재그 계단.
    const offsets = <double>[0, -85, -150, -100, -20, 65, 145, 160, 75, -10];

    final centerX = screen.x / 2;
    for (var i = 0; i < platformCount; i++) {
      // i=0이 가장 아래(바닥에서 한 칸 위), i가 커질수록 위로.
      final topY = groundTop - stepY * (i + 1);
      // 발판 가운데 x → 왼쪽 끝 x, 화면 밖으로 나가지 않게 보정.
      final leftX = (centerX + offsets[i] - platformWidth / 2)
          .clamp(0.0, screen.x - platformWidth)
          .toDouble();

      add(Platform(
        index: i,
        size: Vector2(platformWidth, kPlatformHeight),
        position: Vector2(leftX, topY),
        // 가장 위(마지막) 발판이 스테이지 클리어 지점.
        isGoal: i == platformCount - 1,
      ));
    }
  }

  /// 흑백 낙서 세상의 분위기를 내는 배경 데코레이션을 흩뿌려 배치한다.
  ///
  /// 발판과 같은 칸 높이([stepY]) 체계를 공유하되, '반 칸' 어긋난 위치에
  /// 두어 지그재그 발판 사이사이의 빈 공간을 채운다. 좌우 오프셋도 발판과
  /// 엇갈리게 주어, 몽이가 올라갈 때 낙서가 이정표·스케치북 배경이 된다.
  /// 모든 낙서는 priority -1이라 몽이·발판보다 항상 뒤에 그려진다.
  void _spawnDoodles(Vector2 screen, double groundTop) {
    const platformCount = 10;
    const topMargin = 70.0;

    final climbableHeight = groundTop - topMargin;
    final stepY =
        (climbableHeight / (platformCount + 1)).clamp(0.0, 78.0).toDouble();
    final centerX = screen.x / 2;

    // (모양, 가로 오프셋, 칸 번호(소수=반 칸), 크기, 시드)
    const placements = <(DoodleType, double, double, double, int)>[
      (DoodleType.cloud, 155, 1.5, 72, 11),
      (DoodleType.star, -165, 2.6, 40, 22),
      (DoodleType.arrow, 125, 3.5, 52, 33),
      (DoodleType.cloud, -135, 4.6, 66, 44),
      (DoodleType.star, 175, 5.5, 36, 55),
      (DoodleType.arrow, -145, 6.6, 54, 66),
      (DoodleType.star, 120, 7.5, 46, 77),
      (DoodleType.cloud, -125, 8.6, 62, 88),
      (DoodleType.star, 40, 9.6, 38, 99),
    ];

    for (final (type, dx, step, size, seed) in placements) {
      // anchor가 center라 position이 낙서의 한가운데 — 화면 밖으로 나가지 않게 보정.
      final x = (centerX + dx)
          .clamp(size / 2, screen.x - size / 2)
          .toDouble();
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
