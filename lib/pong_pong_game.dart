import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flame/input.dart';

import 'components/clear_banner.dart';
import 'components/fade_overlay.dart';
import 'components/platform.dart';
import 'components/player.dart';
import 'constants.dart';
import 'scenes/stage_1.dart';

/// 게임의 핵심 심장 — FlameGame 메인 클래스.
///
/// 레벨(바닥·발판) 배치는 [Stage1]로 분리했고, 이 클래스는
/// '레벨 + 플레이어 + 카메라' 조립과 승리/패배 루프 조율을 책임진다.
///
/// - [HasKeyboardHandlerComponents] : 자식 컴포넌트(몽이 등)가 키보드 입력을
///   감지할 수 있도록 키 이벤트를 컴포넌트 트리 전체로 전파하는 믹스인.
class PongPongGame extends FlameGame with HasKeyboardHandlerComponents {
  /// 스테이지 클리어 여부 — true가 되면 몽이 동작이 멈춘다.
  bool isStageCleared = false;

  /// 낙사 리셋 연출 진행 중 여부 — true 동안 몽이 동작이 멈춘다.
  bool isResetting = false;

  late final Player _player;
  late final FadeOverlay _fadeOverlay;

  /// 게임 캔버스 배경색 — constants.dart의 파스텔 소프트 화이트.
  @override
  Color backgroundColor() => kBackgroundColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1) 레벨 — 바닥·발판 배치는 Stage1이 전담 (카메라가 비추도록 world에).
    world.add(Stage1());

    // 2) 주인공 '몽이' — 시작 발판 위에 소환.
    final groundTop = size.y - kGroundHeight;
    _player = Player()
      ..position = Vector2(size.x / 2, groundTop - kPlayerSize / 2);
    world.add(_player);

    // 3) 카메라 — 가로는 화면 중앙에 고정, 세로(y축)로만 몽이를 추적.
    camera.viewfinder.position = Vector2(size.x / 2, _player.position.y);
    camera.follow(_player, verticalOnly: true);

    // 4) 페이드 오버레이 — 화면 고정 UI라 viewport에 올린다(맨 위 렌더).
    _fadeOverlay = FadeOverlay(size: size);
    camera.viewport.add(_fadeOverlay);
  }

  /// 최종 발판 안착 시 호출 — 축하 배너를 띄우고 게임 진행을 멈춘다.
  ///
  /// [isStageCleared]가 true가 되면 [Player]가 update를 스스로 멈추므로,
  /// 게임은 계속 렌더되며 배너의 등장 연출만 재생된다.
  void onStageClear() {
    if (isStageCleared) return;
    isStageCleared = true;
    // 화면 고정 UI → viewport에 추가 (카메라 이동과 무관하게 정중앙 유지).
    camera.viewport.add(ClearBanner(position: size / 2));
  }

  /// 낙사 시작 — 카메라 추적을 멈추고 페이드 연출을 돌린다.
  ///
  /// 페이드 아웃(0.2s) → 화면이 완전히 검을 때 리셋 → 페이드 인(0.3s)의
  /// 순서를 [FadeOverlay]의 프레임 기반 상태 머신이 보장한다.
  void startDeathSequence() {
    if (isResetting) return;
    isResetting = true;

    // 카메라가 더 추락하거나 위로 순간이동하지 않도록 추적을 즉시 정지.
    camera.stop();

    _fadeOverlay.playDeathSequence(
      onFullyDark: () {
        // 화면이 완전히 검은 순간 — 보이지 않게 몽이·발판·카메라를 리셋.
        _player.resetToSpawn();
        resetStage();
        camera.viewfinder.position = Vector2(size.x / 2, _player.position.y);
        camera.follow(_player, verticalOnly: true);
      },
      onComplete: () {
        // 페이드 인까지 모두 끝나면 조작 재개.
        isResetting = false;
      },
    );
  }

  /// 모든 발판을 다시 흑백으로 되돌린다.
  void resetStage() {
    for (final platform in world.descendants().whereType<Platform>()) {
      platform.resetToMonochrome();
    }
  }
}
