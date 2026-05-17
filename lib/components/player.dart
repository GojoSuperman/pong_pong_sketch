import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../pong_pong_game.dart';
import 'ground.dart';
import 'platform.dart';

/// 몽이(Player)의 상태 — CLAUDE.md의 Core State 정의를 따른다.
enum PlayerState {
  /// 가만히 서 있을 때
  idle,

  /// 좌우로 이동 중일 때
  running,

  /// 첫 번째 점프 상승 중일 때
  jumping,

  /// 2단 점프 상승 중일 때
  doubleJumping,

  /// 공중에서 낙하 중일 때
  falling,

  /// 함정에 부딪혔을 때
  hit,
}

/// 주인공 '몽이' 컴포넌트.
///
/// - 입력(Input): [onKeyEvent] — 키보드 좌우 이동 / 점프
/// - 물리(Physics): [update] — 중력·속도 기반 위치 계산
/// - 비주얼(Render): [render] — 임시 프로토타입 그래픽
///
/// CLAUDE.md 규칙대로 입력 로직과 물리 로직을 분리해 관리한다.
class Player extends PositionComponent
    with KeyboardHandler, HasGameReference<PongPongGame> {
  Player()
      : super(
          size: Vector2.all(kPlayerSize),
          anchor: Anchor.center,
        );

  /// 몽이의 현재 상태 (기본값: idle).
  PlayerState state = PlayerState.idle;

  /// 속도 벡터 (px/s). x: 좌우, y: 상하(양수 = 아래 방향).
  final Vector2 _velocity = Vector2.zero();

  /// 현재 입력된 좌우 방향: -1(왼쪽), 0(정지), 1(오른쪽).
  int _horizontalDirection = 0;

  /// 바라보는 방향: 1(오른쪽), -1(왼쪽) — 렌더 시 시선 처리에 사용.
  int _facing = 1;

  /// 남은 점프 가능 횟수. 2 → 1단, 1 → 2단까지 허용.
  int _jumpsRemaining = 2;

  /// 처음 소환 위치 — 낙사 시 이 자리로 리셋한다.
  late final Vector2 _spawnPosition;

  // ── 렌더용 Paint (매 프레임 재생성 방지를 위해 필드로 보관) ──
  final Paint _fillPaint = Paint()
    ..color = kMonochromeFill
    ..style = PaintingStyle.fill;

  final Paint _outlinePaint = Paint()
    ..color = kOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kOutlineWidth;

  final Paint _eyePaint = Paint()
    ..color = kOutlineColor
    ..style = PaintingStyle.fill;

  // ─────────────────────────────────────────────
  // 라이프사이클
  // ─────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // 소환 시점의 위치를 낙사 리셋 기준점으로 저장.
    _spawnPosition = position.clone();
  }

  // ─────────────────────────────────────────────
  // 입력 처리 (Keyboard)
  // ─────────────────────────────────────────────
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // 좌우 이동: A/D 또는 좌우 방향키 (현재 눌린 키 집합으로 판정)
    final isLeft = keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final isRight = keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight);

    _horizontalDirection = (isRight ? 1 : 0) - (isLeft ? 1 : 0);
    if (_horizontalDirection != 0) {
      _facing = _horizontalDirection;
    }

    // 점프: Space / 위 방향키 — 키를 '누르는 순간'에만 발동 (길게 누름·반복 제외)
    final isJumpKey = event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (event is KeyDownEvent && isJumpKey) {
      _jump();
    }

    // true 반환 → 다른 컴포넌트로도 키 이벤트 계속 전파.
    return true;
  }

  /// 1단/2단 점프를 발동한다.
  void _jump() {
    if (_jumpsRemaining <= 0) return;

    // 첫 점프는 강하게, 2단 점프는 부드럽게 약간 약하게.
    final isFirstJump = _jumpsRemaining == 2;
    _velocity.y = isFirstJump ? -kJumpForce : -kDoubleJumpForce;
    _jumpsRemaining--;

    state = isFirstJump ? PlayerState.jumping : PlayerState.doubleJumping;
  }

  // ─────────────────────────────────────────────
  // 물리 연출 (Update)
  // ─────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);

    // 클리어/낙사 연출 중에는 몽이 동작 정지 (게임은 계속 렌더 → 연출 재생).
    if (game.isStageCleared || game.isResetting) return;

    // 직전 프레임의 발 끝·머리 끝 위치 — 발판 '통과' 판정에 사용.
    final previousBottom = position.y + height / 2;
    final previousTop = position.y - height / 2;

    // 1) 중력 적용 (낙하 속도는 최대치로 제한)
    _velocity.y += kGravity * dt;
    if (_velocity.y > kMaxFallSpeed) {
      _velocity.y = kMaxFallSpeed;
    }

    // 2) 좌우 이동 속도 적용
    _velocity.x = _horizontalDirection * kMoveSpeed;

    // 3) 위치 갱신
    position += _velocity * dt;

    // 4) 충돌·판정.
    final headBumped = _checkHeadBump(previousTop); // 발판 밑 머리 충돌
    if (!headBumped) {
      _checkPlatformLanding(previousBottom); // 발판 착지 (+ 클리어 감지)
    }
    _checkGroundLanding(previousBottom); // 시작 발판 착지
    _checkFallDeath(); // 낙사 → 리셋

    // 5) 상태 갱신
    _updateState();
  }

  /// 공중 발판(Platform) 착지 판정.
  ///
  /// 떨어지는 중([_velocity].y > 0)이고, 발 끝이 이번 프레임에 발판 윗면을
  /// '통과'했으며 가로 범위가 겹치면 착지 처리한다.
  /// 정식 충돌 엔진 전 단계라 y좌표 비교만으로 심플하게 처리한다.
  void _checkPlatformLanding(double previousBottom) {
    // 상승 중(점프)에는 발판을 통과 — 떨어질 때만 착지.
    if (_velocity.y <= 0) return;

    final currentBottom = position.y + height / 2;
    final left = position.x - width / 2;
    final right = position.x + width / 2;

    // 발판은 world > Stage1 아래에 있으므로 descendants로 트리 전체를 훑는다.
    for (final platform in game.world.descendants().whereType<Platform>()) {
      // Platform anchor는 topLeft → position.y가 윗면, position.x가 왼쪽 끝.
      final platformTop = platform.position.y;
      final platformLeft = platform.position.x;
      final platformRight = platform.position.x + platform.size.x;

      // 가로 범위가 겹치는지
      final overlapsHorizontally = right > platformLeft && left < platformRight;
      // 이번 프레임에 발 끝이 발판 윗면을 통과(가로지름)했는지
      final crossedTop =
          previousBottom <= platformTop && currentBottom >= platformTop;

      if (overlapsHorizontally && crossedTop) {
        // 착지 — 발 끝을 발판 윗면에 맞추고 낙하 정지, 점프 회복.
        position.y = platformTop - height / 2;
        _velocity.y = 0;
        _jumpsRemaining = 2;
        // [핵심] 밟은 발판을 파스텔톤으로 전환.
        platform.changeToColored();

        // 최종 발판에 안착하면 스테이지 클리어.
        if (platform.isGoal) {
          game.onStageClear();
        }
        return; // 한 프레임에 한 발판만 착지.
      }
    }
  }

  /// 시작 발판(Ground) 착지 판정.
  ///
  /// Ground는 더 이상 화면 전폭 '무적 바닥'이 아니라 작은 시작 발판이므로,
  /// 공중 발판과 똑같이 '가로 범위가 겹칠 때만' 착지한다.
  /// 발판 밖이면 잡아주지 않으므로 낭떠러지로 떨어진다.
  void _checkGroundLanding(double previousBottom) {
    if (_velocity.y <= 0) return; // 떨어질 때만 착지.

    final currentBottom = position.y + height / 2;
    final left = position.x - width / 2;
    final right = position.x + width / 2;

    for (final ground in game.world.descendants().whereType<Ground>()) {
      final groundTop = ground.position.y;
      final groundLeft = ground.position.x;
      final groundRight = ground.position.x + ground.size.x;

      final overlapsHorizontally = right > groundLeft && left < groundRight;
      final crossedTop =
          previousBottom <= groundTop && currentBottom >= groundTop;

      if (overlapsHorizontally && crossedTop) {
        // 시작 발판에 안착 — 발 끝을 윗면에 맞추고 낙하 정지, 점프 회복.
        position.y = groundTop - height / 2;
        _velocity.y = 0;
        _jumpsRemaining = 2;
        return;
      }
    }
  }

  /// 발판 밑에서 머리를 들이받는 충돌 판정.
  ///
  /// 상승 중([_velocity].y < 0) 머리 끝이 이번 프레임에 발판 바닥면을
  /// 아래→위로 통과하려 하고 가로 범위가 겹치면, 상승을 막고 아래로
  /// 살짝 밀어내 자연스럽게 낙하시킨다.
  /// 머리를 찧었으면 true를 반환한다 (같은 프레임 발판 착지 판정 생략용).
  bool _checkHeadBump(double previousTop) {
    if (_velocity.y >= 0) return false; // 상승 중일 때만.

    final currentTop = position.y - height / 2;
    final left = position.x - width / 2;
    final right = position.x + width / 2;

    for (final platform in game.world.descendants().whereType<Platform>()) {
      // 발판 바닥면 = position.y(윗면) + 두께.
      final platformBottom = platform.position.y + platform.size.y;
      final platformLeft = platform.position.x;
      final platformRight = platform.position.x + platform.size.x;

      final overlapsHorizontally = right > platformLeft && left < platformRight;
      // 이번 프레임에 머리 끝이 발판 바닥면을 통과(가로지름)했는지.
      final crossedBottom =
          previousTop >= platformBottom && currentTop <= platformBottom;

      if (overlapsHorizontally && crossedBottom) {
        // 머리를 쿵 — 머리 끝을 발판 바닥면 바로 아래에 맞추고 상승 정지.
        position.y = platformBottom + height / 2;
        // 아래로 살짝 밀어내 자연스럽게 낙하 시작.
        _velocity.y = kHeadBumpRebound;
        state = PlayerState.falling;
        return true; // 한 발판만 처리.
      }
    }
    return false;
  }

  /// 낙사 판정 — 화면 한참 아래로 떨어지면 죽음 연출(페이드)을 시작한다.
  void _checkFallDeath() {
    if (position.y > game.size.y + kPlayerSize * 2) {
      game.startDeathSequence();
    }
  }

  /// 몽이를 처음 소환 위치로 되돌린다.
  ///
  /// 낙사 페이드 연출 도중 '화면이 완전히 검은 순간' 게임이 호출한다.
  /// (발판 리셋은 게임이 별도로 처리한다.)
  void resetToSpawn() {
    position.setFrom(_spawnPosition);
    _velocity.setZero();
    _jumpsRemaining = 2;
    state = PlayerState.falling;
  }

  /// 속도/입력 기반으로 [state]를 갱신한다.
  void _updateState() {
    if (state == PlayerState.hit) return;

    if (_velocity.y < 0) {
      // 상승 중 — 점프 횟수로 1단/2단 구분
      state = _jumpsRemaining == 0
          ? PlayerState.doubleJumping
          : PlayerState.jumping;
    } else if (_velocity.y > 0) {
      state = PlayerState.falling;
    } else if (_horizontalDirection != 0) {
      state = PlayerState.running;
    } else {
      state = PlayerState.idle;
    }
  }

  // ─────────────────────────────────────────────
  // 비주얼 렌더링 (Render)
  // ─────────────────────────────────────────────
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 둥글둥글한 라운드 사각형 몸체 (핸드드로잉 느낌).
    final body = RRect.fromRectAndRadius(
      Offset.zero & Size(width, height),
      Radius.circular(width * 0.35),
    );

    // 1) 안쪽 면 채우기 — 밟기 전 흑백 톤(흰 면).
    canvas.drawRRect(body, _fillPaint);

    // 2) 검은 외곽선 2dp — 핸드드로잉 흉내.
    canvas.drawRRect(body, _outlinePaint);

    // 3) 귀여운 눈 두 개 — 바라보는 방향으로 살짝 치우치게.
    final eyeY = height * 0.42;
    final eyeGap = width * 0.18;
    final lookShift = _facing * width * 0.06;
    final eyeRadius = width * 0.07;
    final centerX = width / 2 + lookShift;
    canvas.drawCircle(Offset(centerX - eyeGap, eyeY), eyeRadius, _eyePaint);
    canvas.drawCircle(Offset(centerX + eyeGap, eyeY), eyeRadius, _eyePaint);
  }
}
