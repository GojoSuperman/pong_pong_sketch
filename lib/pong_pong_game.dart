import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';

import 'components/clear_banner.dart';
import 'components/doodle_decoration.dart';
import 'components/fade_overlay.dart';
import 'components/firework_particle.dart';
import 'components/platform.dart';
import 'components/player.dart';
import 'components/purification_hud.dart';
import 'components/sketchbook_background.dart';
import 'constants.dart';
import 'helpers/audio_manager.dart';
import 'scenes/stage_1.dart';
import 'scenes/stage_2.dart';
import 'scenes/stage_3.dart';
import 'scenes/stage_4.dart';

/// 게임의 핵심 심장 — FlameGame 메인 클래스.
///
/// 레벨(바닥·발판) 배치는 [Stage1]로 분리했고, 이 클래스는
/// '레벨 + 플레이어 + 카메라' 조립과 승리/패배 루프 조율을 책임진다.
///
/// - [HasKeyboardHandlerComponents] : 자식 컴포넌트(몽이 등)가 키보드 입력을
///   감지할 수 있도록 키 이벤트를 컴포넌트 트리 전체로 전파하는 믹스인.
class PongPongGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  /// 카메라를 고정 해상도([kGameWidth] × [kGameHeight])로 설정한다.
  ///
  /// 창 크기와 무관하게 일관된 레이아웃을 보장하고, 남는 공간은
  /// 카메라가 자동으로 레터박스(여백) 처리한다.
  PongPongGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: kGameWidth,
            height: kGameHeight,
          ),
        );

  /// 스테이지 클리어 여부 — true가 되면 몽이 동작이 멈춘다.
  bool isStageCleared = false;

  /// 낙사 리셋 연출 진행 중 여부 — true 동안 몽이 동작이 멈춘다.
  bool isResetting = false;

  late final Player _player;
  late final FadeOverlay _fadeOverlay;

  /// 현재 진행 중인 스테이지 컴포넌트 (Stage1 / Stage2).
  late Component _stage;

  /// 현재 스테이지 번호 (1 또는 2) — 스테이지 전환을 한 번만 하도록 가드.
  int _currentStage = 1;

  /// 클리어 배너 — 스테이지 전환 시 제거할 수 있도록 참조를 보관.
  ClearBanner? _clearBanner;

  /// 배너 폭죽 반복 타이머 — 스테이지 전환 시 멈추도록 참조를 보관.
  TimerComponent? _fireworkTimer;

  /// 배경 낙서(DoodleDecoration)가 몽이와의 거리를 잴 수 있도록
  /// 노출하는 읽기 전용 플레이어 참조.
  Player get player => _player;

  /// 게임 캔버스 배경색 — constants.dart의 파스텔 소프트 화이트.
  @override
  Color backgroundColor() => kBackgroundColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 0) 사운드 인프라 — 오디오를 메모리에 미리 캐시하고 스테이지 1 BGM을
    //    루프 재생한다. 파일 미배치 시 AudioManager가 가드해 게임은
    //    사운드 없이 정상 진행된다.
    await AudioManager.preload();
    AudioManager.startBgm();

    // 1) 레벨 — 스테이지 1을 카메라가 비추는 world에 올린다.
    _stage = Stage1();
    world.add(_stage);

    // 2) 주인공 '몽이' — 시작 베이스 땅(화면 최하단) 바로 위에 소환.
    _player = Player()
      ..position = Vector2(kGameWidth / 2, kStageGroundTop - kPlayerSize / 2);
    world.add(_player);

    // 3) 카메라 — 화면 최하단을 비추며 시작, 몽이가 중앙 위로 오르면 스크롤.
    _setupCamera();

    // 4) 페이드 오버레이 — 고정 해상도 전체를 덮는 화면 고정 UI(viewport).
    _fadeOverlay = FadeOverlay(size: Vector2(kGameWidth, kGameHeight));
    camera.viewport.add(_fadeOverlay);

    // 5) 정화도 HUD — 화면 상단 중앙에 고정(viewport).
    camera.viewport.add(
      PurificationHud(onMilestone: _onPurificationMilestone)
        ..position = Vector2(kGameWidth / 2, kHudTopMargin),
    );
  }

  /// 카메라를 스테이지 시작 상태로 맞춘다 — 화면 맨 바닥(레벨 바닥)을 비춘다.
  ///
  /// 이후 세로 추적·바닥 잠금은 [update]가 매 프레임 처리한다.
  void _setupCamera() {
    camera.viewfinder.position = Vector2(kGameWidth / 2, kGameHeight / 2);
  }

  /// 매 프레임 카메라를 갱신 — 몽이를 세로로 추적하되 뷰파인더 y를 화면
  /// 절반 이하로 잠근다.
  ///
  /// 그래서 시작 시엔 화면 최하단(레벨 바닥)을 비추고, 몽이가 화면 중앙 위로
  /// 치고 올라가야 비로소 카메라가 위로 부드럽게 따라 스크롤된다. 클리어·낙사
  /// 연출 중([isStageCleared]/[isResetting])엔 카메라를 건드리지 않는다.
  @override
  void update(double dt) {
    super.update(dt);
    if (isStageCleared || isResetting) return;
    // 뷰파인더 y를 [0, 화면 절반]으로 잠가 레벨 바닥 아래 빈 공간을 막는다.
    final followY = _player.position.y.clamp(0.0, kGameHeight / 2).toDouble();
    camera.viewfinder.position = Vector2(kGameWidth / 2, followY);
  }

  /// 정화도 마일스톤(25/50/75/100%) 달성 시 [PurificationHud]가 호출하는 훅.
  ///
  /// 25/50/75%는 HUD 자체 펄스로만 가볍게 피드백하고, 100%에서 글로벌 무지개
  /// 정화 연출을 발동한다. (축하 폭죽은 클리어 배너 주변에만 집중된다 —
  /// [_playBannerFireworks] 참고.)
  void _onPurificationMilestone(int percent) {
    if (percent >= 100) {
      _applyGlobalPurification();
    }
  }

  /// 클리어 배너 등장과 함께 — 타이틀 주변에서 파스텔 폭죽을 계속 터뜨린다.
  ///
  /// 폭죽을 몽이 주변이 아닌 상단 타이틀 영역에만 집중시킨다. 첫 물결을
  /// 즉시 터뜨린 뒤, 반복 타이머로 다음 스테이지로 넘어갈 때까지 끊임없이
  /// 이어 터뜨려 축하 분위기를 유지한다.
  void _playBannerFireworks() {
    _spawnBannerFireworkWave(); // 첫 물결 — 배너가 나타나는 즉시.
    // 이후 계속 — 주기적으로 반복. 스테이지 전환 시 멈추도록 참조를 보관한다.
    _fireworkTimer = TimerComponent(
      period: kBannerFireworkWaveGap,
      repeat: true,
      onTick: _spawnBannerFireworkWave,
    );
    add(_fireworkTimer!);
  }

  /// 타이틀 배너 주변 다섯 지점에서 파스텔 폭죽 한 물결을 터뜨린다.
  ///
  /// 배너와 같은 viewport에 올려 화면에 고정한다.
  void _spawnBannerFireworkWave() {
    final centerX = kGameWidth / 2;
    const bannerY = kClearBannerY;
    final points = <Vector2>[
      Vector2(centerX - kBannerFireworkSpread, bannerY), // 좌측 모서리
      Vector2(centerX + kBannerFireworkSpread, bannerY), // 우측 모서리
      Vector2(centerX, bannerY - 36), // 타이틀 글자 위쪽
      Vector2(centerX - kBannerFireworkSpread * 0.55, bannerY + 30),
      Vector2(centerX + kBannerFireworkSpread * 0.55, bannerY + 30),
    ];
    for (final point in points) {
      camera.viewport.add(createPurificationFirework(point));
    }
  }

  /// 정화도 100% 달성 시 — 흑백 모눈종이 격자를 파스텔 무지개 톤으로
  /// 물들이는 글로벌 정화 연출을 발동한다.
  void _applyGlobalPurification() {
    // 흑백 모눈종이 격자 → 흐르는 파스텔 무지개.
    for (final background
        in world.descendants().whereType<SketchbookBackground>()) {
      background.purify();
    }
    // 공중에 떠 있는 배경 낙서(별·구름·화살표)들도 파스텔 색으로 채운다.
    for (final doodle in world.descendants().whereType<DoodleDecoration>()) {
      doodle.purify();
    }
  }

  /// 최종 발판 안착 시 호출 — 축하 배너를 띄우고 게임 진행을 멈춘다.
  ///
  /// [isStageCleared]가 true가 되면 [Player]가 update를 스스로 멈추므로,
  /// 게임은 계속 렌더되며 배너의 등장 연출만 재생된다.
  void onStageClear() {
    if (isStageCleared) return;
    isStageCleared = true;
    // 100% 정화 달성 — 기존 BGM을 멈추고 승리 팡파르를 1회 울린다.
    AudioManager.playVictory();
    // 몽이가 상단 배너 아래 공간에서 춤추도록 카메라 시점을 맞춘다.
    // isStageCleared=true라 update의 카메라 추적이 멈춰 이 위치가 유지된다.
    camera.viewfinder.position = Vector2(
      kGameWidth / 2,
      _player.position.y + kGameHeight * kCelebrationCameraLift,
    );
    // 클리어 배너 — 상단 중앙(HUD 아래)에 고정. 전환 시 제거하도록 보관.
    _clearBanner = ClearBanner();
    camera.viewport.add(_clearBanner!);
    // 배너 등장과 동시에 배너 주변에서 파스텔 폭죽이 터진다.
    _playBannerFireworks();
    // 몽이는 그 자리에서 기쁨의 무한 댄스를 시작한다.
    _player.startCelebration();
    // 마지막 스테이지 전이면 — 축하 댄스를 잠시 보여준 뒤 다음 스테이지로 전환.
    if (_currentStage < kStageCount) {
      add(TimerComponent(
        period: kStageClearHoldDuration,
        removeOnFinish: true,
        onTick: _transitionToNextStage,
      ));
    }
  }

  /// 다음 스테이지로 전환 — 화면을 페이드 아웃해 어두운 동안 무대를 교체한다.
  ///
  /// 화면이 완전히 검은 순간: 클리어 화면(배너·폭죽)을 정리하고, 현재 무대를
  /// 떼어낸 뒤 다음 스테이지를 올리고, 몽이·카메라를 시작 상태로 되돌린다.
  void _transitionToNextStage() {
    final next = _currentStage + 1;
    _fadeOverlay.playFadeTransition(
      onFullyDark: () {
        // 1) 클리어 화면 정리 — 배너·폭죽 타이머·남은 폭죽 입자 제거.
        _clearBanner?.removeFromParent();
        _clearBanner = null;
        _fireworkTimer?.removeFromParent();
        _fireworkTimer = null;
        camera.viewport.removeWhere((c) => c is ParticleSystemComponent);
        // 2) 무대 교체 — 현재 스테이지 제거, 다음 스테이지 로드.
        _stage.removeFromParent();
        _currentStage = next;
        _stage = _createStage(next);
        world.add(_stage);
        // 새 스테이지 시작 — 클리어 팡파르 때 멈춘 BGM을 다시 루프 재생한다.
        AudioManager.startBgm();
        // 3) 몽이를 시작 위치로(축하 상태 해제), 카메라를 바닥 기준으로 재설정.
        _player.resetToSpawn();
        _setupCamera();
        // 4) 클리어 플래그 해제 — 몽이가 다시 움직인다.
        isStageCleared = false;
      },
      onComplete: () {},
    );
  }

  /// 스테이지 번호에 해당하는 씬 컴포넌트를 만든다.
  Component _createStage(int stageNumber) => switch (stageNumber) {
        2 => Stage2(),
        3 => Stage3(),
        4 => Stage4(),
        _ => Stage1(),
      };

  /// 낙사 시작 — 카메라 추적을 멈추고 페이드 연출을 돌린다.
  ///
  /// 페이드 아웃(0.2s) → 화면이 완전히 검을 때 리셋 → 페이드 인(0.3s)의
  /// 순서를 [FadeOverlay]의 프레임 기반 상태 머신이 보장한다.
  void startDeathSequence() {
    if (isResetting) return;
    isResetting = true;
    // isResetting=true가 되면 update의 카메라 추적이 멈춰, 페이드 동안
    // 카메라가 추락하거나 순간이동하지 않는다.

    _fadeOverlay.playFadeTransition(
      onFullyDark: () {
        // 화면이 완전히 검은 순간 — 보이지 않게 몽이·발판·카메라를 리셋.
        _player.resetToSpawn();
        resetStage();
        _setupCamera();
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
