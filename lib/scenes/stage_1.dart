import 'package:flame/components.dart';

import '../components/ground.dart';
import '../components/platform.dart';
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

    final screen = game.size;
    final groundTop = screen.y - kGroundHeight;

    // 시작 발판(Ground) — 화면 하단 중앙에 작은 발판 하나로 배치.
    // 화면 전폭이 아니므로 이 발판을 벗어나면 낭떠러지로 떨어진다.
    add(Ground(
      size: Vector2(kGroundWidth, kGroundHeight),
      position: Vector2((screen.x - kGroundWidth) / 2, groundTop),
    ));

    // 점프로 한 칸씩 오를 수 있는 지그재그 발판 10개.
    _spawnClimbablePlatforms(screen, groundTop);
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
}
