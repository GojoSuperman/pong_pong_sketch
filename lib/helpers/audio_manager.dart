import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// 게임의 모든 사운드(BGM·SFX)를 한곳에서 제어하는 정적 사운드 매니저.
///
/// - 게임 [onLoad] 시 [preload]로 오디오를 메모리에 미리 캐시한다.
/// - 각 게임 이벤트(점프·정화·밟기·클리어)에서 정적 메서드를 호출해 재생한다.
///
/// **안정성 원칙:** `assets/audio/` 폴더에 실제 사운드 파일이 아직 없어도
/// 게임이 절대 튕기지 않는다. 프리로드 실패 시 [_ready]가 false로 남아
/// 모든 재생 호출이 조용히 무시되며, 개별 재생도 try-catch로 가드된다.
/// (웹 환경의 자동재생 차단 예외도 동일하게 흡수된다.)
class AudioManager {
  // 정적 유틸리티 클래스 — 인스턴스화 금지.
  AudioManager._();

  // ─────────────────────────────────────────────
  // 🎵 오디오 파일명 상수
  //
  // 유저가 실제 파일을 `assets/audio/` 폴더에 이 이름 그대로 넣으면
  // 바로 매칭되어 재생된다. (assets/audio/README.md 참고)
  // ─────────────────────────────────────────────

  /// 메인 배경음악 — '퐁퐁 스케치 월드' (무한 루프).
  static const String bgmSketchWorld = 'bgm_sketch_world.mp3';

  /// SFX — 몽이 점프.
  static const String sfxJump = 'sfx_jump.mp3';

  /// SFX — 발판 정화(흑백 → 파스텔 착지).
  static const String sfxPurify = 'sfx_purify.mp3';

  /// SFX — 지우개 몬스터 밟기.
  static const String sfxStomp = 'sfx_stomp.mp3';

  /// SFX — 100% 정화 클리어 팡파르.
  static const String sfxVictory = 'sfx_victory.mp3';

  /// 프리로드 대상 — 게임 시작 시 한 번에 캐시할 전체 오디오 클립.
  static const List<String> _allClips = <String>[
    bgmSketchWorld,
    sfxJump,
    sfxPurify,
    sfxStomp,
    sfxVictory,
  ];

  /// 프리로드가 성공해 사운드 재생이 가능한 상태인지.
  ///
  /// false면(=오디오 파일 미배치) 모든 재생 호출이 무시된다.
  static bool _ready = false;

  /// 사운드 재생 가능 여부 (읽기 전용 노출).
  static bool get isReady => _ready;

  // ─────────────────────────────────────────────
  // 프리로드
  // ─────────────────────────────────────────────

  /// 게임 [onLoad]에서 1회 호출 — 모든 오디오를 메모리에 미리 캐시한다.
  ///
  /// 파일이 아직 폴더에 없으면 로드가 실패하지만, 예외를 흡수하고
  /// [_ready]를 false로 둬 게임이 사운드 없이 정상 진행되도록 한다.
  static Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll(_allClips);
      _ready = true;
    } catch (e) {
      _ready = false;
      debugPrint('[AudioManager] 오디오 프리로드 건너뜀 — 파일 미배치: $e');
    }
  }

  // ─────────────────────────────────────────────
  // SFX 재생
  // ─────────────────────────────────────────────

  /// 몽이 점프 효과음.
  static void playJump() => _playSfx(sfxJump);

  /// 발판 정화 효과음 — [Platform.changeToColored]의 중복 가드 뒤에서 호출돼
  /// 발판 한 장당 한 번만 울린다.
  static void playPurify() => _playSfx(sfxPurify);

  /// 지우개 몬스터 밟기 효과음.
  static void playStomp() => _playSfx(sfxStomp);

  /// 단발 효과음을 안전하게 재생한다 — 비차단(fire-and-forget) + 예외 가드.
  static void _playSfx(String file) {
    if (!_ready) return;
    unawaited(_guardedPlay(file));
  }

  /// [FlameAudio.play]를 try-catch로 감싸 비동기 예외까지 흡수한다.
  static Future<void> _guardedPlay(String file) async {
    try {
      await FlameAudio.play(file);
    } catch (e) {
      debugPrint('[AudioManager] SFX 재생 실패 ($file): $e');
    }
  }

  // ─────────────────────────────────────────────
  // BGM 제어
  // ─────────────────────────────────────────────

  /// 배경음악을 무한 루프로 재생한다 — 스테이지(재)시작 시 호출.
  ///
  /// [FlameAudio.bgm]은 기본적으로 루프 모드라 자동으로 무한 반복된다.
  static void startBgm() {
    if (!_ready) return;
    unawaited(_guardedBgm(() => FlameAudio.bgm.play(bgmSketchWorld)));
  }

  /// 배경음악을 멈춘다 — 클리어 팡파르 직전 부드럽게 정지.
  static void stopBgm() {
    unawaited(_guardedBgm(() => FlameAudio.bgm.stop()));
  }

  /// BGM 조작을 try-catch로 감싸 예외를 흡수한다.
  static Future<void> _guardedBgm(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('[AudioManager] BGM 조작 실패: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 복합 연출
  // ─────────────────────────────────────────────

  /// 100% 정화 클리어 — 기존 BGM을 멈추고 승리 팡파르를 1회 재생한다.
  static void playVictory() {
    stopBgm();
    _playSfx(sfxVictory);
  }
}
