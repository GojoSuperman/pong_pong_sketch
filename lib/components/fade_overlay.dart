import 'dart:ui';

import 'package:flame/components.dart';

/// 페이드 연출 단계.
enum _FadePhase { idle, fadingOut, fadingIn }

/// 화면 전체를 덮는 검은 페이드 오버레이.
///
/// 낙사 시 화면을 부드럽게 어둡혔다(Fade Out) 다시 밝히며(Fade In),
/// 완전히 어두워진 순간 콜백을 호출해 그 사이에 리셋이 일어나게 한다.
///
/// Future/비동기 없이 [update] 기반 상태 머신으로만 동작하므로
/// 타이밍이 결정적이고, 리셋 로직과 꼬일 여지가 없다.
class FadeOverlay extends PositionComponent {
  FadeOverlay({required Vector2 size})
      : super(size: size, priority: 1000);

  /// 페이드 아웃 시간 (초).
  static const double _fadeOutDuration = 0.2;

  /// 페이드 인 시간 (초).
  static const double _fadeInDuration = 0.3;

  _FadePhase _phase = _FadePhase.idle;

  /// 어둠 정도 — 0(투명) ~ 1(완전 검정).
  double _darkness = 0;

  /// 현재 단계 경과 시간 (초).
  double _elapsed = 0;

  VoidCallback? _onFullyDark;
  VoidCallback? _onComplete;

  final Paint _paint = Paint();

  /// 연출 진행 중인지 여부.
  bool get isPlaying => _phase != _FadePhase.idle;

  /// 낙사 연출 시작 — 어두워졌다(0.2s) 다시 밝아진다(0.3s).
  ///
  /// [onFullyDark] : 화면이 완전히 검은 순간 1회 호출 (이때 리셋 처리).
  /// [onComplete]  : 페이드 인까지 모두 끝난 뒤 1회 호출.
  void playDeathSequence({
    required VoidCallback onFullyDark,
    required VoidCallback onComplete,
  }) {
    if (_phase != _FadePhase.idle) return; // 연출 도중 중복 시작 방지.
    _onFullyDark = onFullyDark;
    _onComplete = onComplete;
    _phase = _FadePhase.fadingOut;
    _elapsed = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_phase == _FadePhase.idle) return;

    _elapsed += dt;

    if (_phase == _FadePhase.fadingOut) {
      _darkness = clampDouble(_elapsed / _fadeOutDuration, 0, 1);
      if (_elapsed >= _fadeOutDuration) {
        // 화면이 완전히 검을 때 — 보이지 않게 리셋.
        _darkness = 1;
        _onFullyDark?.call();
        _phase = _FadePhase.fadingIn;
        _elapsed = 0;
      }
    } else {
      // fadingIn — 점점 밝아진다.
      _darkness = clampDouble(1 - _elapsed / _fadeInDuration, 0, 1);
      if (_elapsed >= _fadeInDuration) {
        _darkness = 0;
        _phase = _FadePhase.idle;
        final done = _onComplete;
        _onFullyDark = null;
        _onComplete = null;
        done?.call();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_darkness <= 0) return; // 투명할 땐 그릴 필요 없음.
    _paint.color = Color.fromRGBO(0, 0, 0, _darkness);
    canvas.drawRect(Offset.zero & Size(width, height), _paint);
  }
}
