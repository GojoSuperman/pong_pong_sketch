import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../helpers/audio_manager.dart';
import '../pong_pong_game.dart';
import 'dust_particle.dart';
import 'ground.dart';
import 'platform.dart';
import 'special_platforms.dart';

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

  /// 스테이지를 100% 정화·클리어해 기뻐 춤추는 중일 때
  celebrating,
}

/// 몽이가 가만히 있을 때 능청스럽게 부리는 딴짓(Idle Fidget) 종류.
enum FidgetType {
  /// 딴짓 안 함 (평상시).
  none,

  /// 동작 1 — 눈을 좌우 끝으로 능청스럽게 굴린다.
  eyeRoll,

  /// 동작 2 — 웅크렸다 뿅 튀며 파스텔 핑크 방귀 먼지를 뿜는다.
  fart,

  /// 동작 3 — 숨겨둔 손이 나와 머리 위를 슥슥 긁는다.
  headScratch,
}

/// 주인공 '몽이' 컴포넌트.
///
/// - 입력(Input): [onKeyEvent] — 키보드 좌우 이동 / 점프
/// - 물리(Physics): [update] — 중력·속도 기반 위치 계산
/// - 비주얼(Render): [render] — 임시 프로토타입 그래픽
///
/// CLAUDE.md 규칙대로 입력 로직과 물리 로직을 분리해 관리한다.
class Player extends PositionComponent
    with KeyboardHandler, HasGameReference<PongPongGame>, CollisionCallbacks {
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

  /// 이번 프레임에 미끄러운 발판(SlipperyPlatform) 위에 서 있는지.
  /// true면 좌우 속도가 즉시 멈추지 않고 관성으로 미끄러진다.
  bool _onSlipperyPlatform = false;

  /// 지우개에게 맞은 뒤 넉백·무적이 유지되는 남은 시간 (초).
  double _hitTimer = 0;

  /// 처음 소환 위치 — 낙사 시 이 자리로 리셋한다.
  late final Vector2 _spawnPosition;

  // ── 딴짓(Idle Fidget) 상태 ──

  /// 무작위 딴짓 선택용 난수기.
  final Random _rng = Random();

  /// idle 상태가 끊김 없이 유지된 시간 (초). [kFidgetTriggerDelay] 도달 시 발동.
  double _idleTime = 0;

  /// 현재 수행 중인 딴짓 (기본값: none).
  FidgetType _fidget = FidgetType.none;

  /// 현재 딴짓 연출이 시작된 뒤 흐른 시간 (초).
  double _fidgetElapsed = 0;

  /// 방귀 먼지를 이미 뿜었는지 — 연출당 한 번만 방출하도록 막는 가드.
  bool _fartPuffEmitted = false;

  // ── 클리어 축하(Celebration) 상태 ──

  /// 축하 점프의 기준 바닥 y — 클리어 시점의 착지 y를 굳혀, 제자리에서 튄다.
  double _celebrationBaseY = 0;

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
    // 지우개(EraserEnemy)와의 충돌 감지를 위한 히트박스.
    add(RectangleHitbox());
  }

  // ─────────────────────────────────────────────
  // 입력 처리 (Keyboard)
  // ─────────────────────────────────────────────
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // 클리어 축하 중에는 조작을 막는다 — 몽이는 기쁨의 댄스만 춘다.
    if (state == PlayerState.celebrating) return true;

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

    // 입력으로 움직임이 시작되면 하던 딴짓을 즉시 중단한다.
    final movementStarted =
        _horizontalDirection != 0 || (event is KeyDownEvent && isJumpKey);
    if (movementStarted) {
      _cancelFidget();
    }

    // true 반환 → 다른 컴포넌트로도 키 이벤트 계속 전파.
    return true;
  }

  /// 1단/2단 점프를 발동한다.
  void _jump() {
    if (_jumpsRemaining <= 0) return;

    // 점프 효과음 — 1단·2단 점프 모두에서 울린다.
    AudioManager.playJump();

    // 첫 점프는 강하게, 2단 점프는 부드럽게 약간 약하게.
    final isFirstJump = _jumpsRemaining == 2;
    _velocity.y = isFirstJump ? -kJumpForce : -kDoubleJumpForce;
    _jumpsRemaining--;

    state = isFirstJump ? PlayerState.jumping : PlayerState.doubleJumping;

    // 1단·2단 점프 모두 — 발밑에서 파스텔 먼지 구름이 '퐁' 피어오른다.
    // world에 올려 몽이는 위로 솟고 먼지는 점프 지점에 남아 사라지게 한다.
    final foot = position + Vector2(0, height / 2);
    game.world.add(createJumpDust(foot));
  }

  // ─────────────────────────────────────────────
  // 물리 연출 (Update)
  // ─────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);

    // 클리어 축하 중 — 일반 물리 대신 '제자리 퐁퐁 댄스'만 돌린다.
    if (state == PlayerState.celebrating) {
      _updateCelebration(dt);
      return;
    }

    // 클리어/낙사 연출 중에는 몽이 동작 정지 (게임은 계속 렌더 → 연출 재생).
    if (game.isStageCleared || game.isResetting) return;

    // 지우개에게 맞은 hit(넉백) 상태 — 일정 시간 입력을 무시하다 회복한다.
    final isHitRecovering = state == PlayerState.hit;
    if (isHitRecovering) {
      _hitTimer -= dt;
      if (_hitTimer <= 0) state = PlayerState.falling; // 넉백 끝 — 회복.
    }

    // 직전 프레임의 발 끝·머리 끝 위치 — 발판 '통과' 판정에 사용.
    final previousBottom = position.y + height / 2;
    final previousTop = position.y - height / 2;

    // 1) 중력 적용 (낙하 속도는 최대치로 제한)
    _velocity.y += kGravity * dt;
    if (_velocity.y > kMaxFallSpeed) {
      _velocity.y = kMaxFallSpeed;
    }

    // 2) 좌우 이동 속도 — hit 넉백 중엔 입력을 무시(튕긴 속도를 유지).
    //    그 외엔 일반 발판은 즉시, 미끄러운 발판은 관성으로 수렴한다.
    if (!isHitRecovering) {
      final targetVx = _horizontalDirection * kMoveSpeed;
      if (_onSlipperyPlatform) {
        // 마찰이 약해 목표 속도로 천천히 수렴 — 멈춰도 쭈르륵 미끄러진다.
        final friction = (kSlipperyFriction * dt).clamp(0.0, 1.0);
        _velocity.x += (targetVx - _velocity.x) * friction;
      } else {
        _velocity.x = targetVx;
      }
    }

    // 3) 위치 갱신
    position += _velocity * dt;

    // 4) 충돌·판정.
    _onSlipperyPlatform = false; // 이번 프레임 착지 결과로 다시 채워진다.
    final headBumped = _checkHeadBump(previousTop); // 발판 밑 머리 충돌
    if (!headBumped) {
      _checkPlatformLanding(previousBottom); // 발판 착지 (+ 클리어 감지)
    }
    _checkGroundLanding(previousBottom); // 시작 발판 착지
    _checkFallDeath(); // 낙사 → 리셋

    // 5) 상태 갱신
    _updateState();

    // 6) idle 딴짓(Idle Fidget) 갱신
    _updateFidget(dt);
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
      // 꺼진 점선 발판(BlinkingPlatform)은 딛지 못한다 — 건너뛴다.
      if (platform is BlinkingPlatform && !platform.isActive) continue;

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
        // 착지 — 발 끝을 발판 윗면에 맞춘다.
        position.y = platformTop - height / 2;
        _jumpsRemaining = 2;
        // 트램펄린 발판 — 닿는 즉시 초고공으로 튕겨 올린다. 그 외엔 낙하 정지.
        if (platform is BouncyPlatform) {
          _velocity.y = -kBouncyJumpForce;
        } else {
          _velocity.y = 0;
        }
        // 움직이는 발판 위에선, 발판이 이번 프레임에 움직인 만큼 몽이도
        // 함께 실려 간다 (발판이 몽이보다 먼저 update돼 lastDx가 최신값).
        if (platform is MovingPlatform) {
          position.x += platform.lastDx;
        }
        // 미끄러운 발판 위에선 마찰이 약해진다 — 다음 프레임 좌우 속도에 반영.
        if (platform is SlipperyPlatform) {
          _onSlipperyPlatform = true;
        }
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
      // 꺼진 점선 발판은 충돌하지 않는다 — 건너뛴다.
      if (platform is BlinkingPlatform && !platform.isActive) continue;

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
    if (position.y > kGameHeight + kPlayerSize * 2) {
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
    _cancelFidget();
  }

  /// 속도/입력 기반으로 [state]를 갱신한다.
  void _updateState() {
    // hit·celebrating은 별도 제어 상태라 속도 기반 갱신에서 제외한다.
    if (state == PlayerState.hit || state == PlayerState.celebrating) return;

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
  // 딴짓 (Idle Fidget)
  // ─────────────────────────────────────────────

  /// idle 지속 시간을 적산하고, 임계치를 넘으면 무작위 딴짓을 발동·진행한다.
  ///
  /// idle이 아니면(이동·점프 등) 진행 중인 딴짓을 즉시 정리하고 타이머를 리셋한다.
  void _updateFidget(double dt) {
    // idle이 아니면 — 딴짓 중단 + 대기 타이머 리셋.
    if (state != PlayerState.idle) {
      if (_fidget != FidgetType.none) _cancelFidget();
      _idleTime = 0;
      return;
    }

    // 딴짓 진행 중 — 연출 시간 적산.
    if (_fidget != FidgetType.none) {
      _fidgetElapsed += dt;

      // 방귀: 웅크림이 끝나는 순간 핑크 먼지를 단 한 번만 방출.
      if (_fidget == FidgetType.fart &&
          !_fartPuffEmitted &&
          _fidgetElapsed >= kFidgetFartCrouchPhase) {
        _emitFartPuff();
        _fartPuffEmitted = true;
      }

      // 연출이 끝나면 종료 → 다시 대기 타이머가 돌기 시작한다.
      if (_fidgetElapsed >= _fidgetDuration) _endFidget();
      return;
    }

    // 가만히 서 있는 시간 적산 → 임계치 도달 시 무작위 딴짓 시작.
    _idleTime += dt;
    if (_idleTime >= kFidgetTriggerDelay) _startRandomFidget();
  }

  /// 현재 딴짓 연출의 총 길이 (초).
  double get _fidgetDuration => switch (_fidget) {
        FidgetType.none => 0,
        FidgetType.eyeRoll =>
          kFidgetEyeRollSidePhase * 2 + kFidgetEyeRollReturnPhase,
        FidgetType.fart => kFidgetFartCrouchPhase +
            kFidgetFartPopPhase +
            kFidgetFartSettlePhase,
        FidgetType.headScratch => kFidgetScratchEmergePhase +
            kFidgetScratchActivePhase +
            kFidgetScratchRetractPhase,
      };

  /// 3종 딴짓 중 하나를 무작위로 골라 시작한다.
  void _startRandomFidget() {
    const candidates = [
      FidgetType.eyeRoll,
      FidgetType.fart,
      FidgetType.headScratch,
    ];
    _fidget = candidates[_rng.nextInt(candidates.length)];
    _fidgetElapsed = 0;
    _fartPuffEmitted = false;
  }

  /// 딴짓 연출이 정상적으로 끝났을 때 — 상태를 비우고 대기 타이머를 리셋한다.
  void _endFidget() {
    _fidget = FidgetType.none;
    _fidgetElapsed = 0;
    _idleTime = 0;
  }

  /// 딴짓이 입력 등으로 중단됐을 때 — 모든 딴짓 상태를 즉시 초기화한다.
  void _cancelFidget() {
    _fidget = FidgetType.none;
    _fidgetElapsed = 0;
    _fartPuffEmitted = false;
    _idleTime = 0;
  }

  /// 동작 1 — 눈 굴리기: 시선 가로 오프셋(px)을 연출 시간에 맞춰 계산한다.
  ///
  /// 정중앙 → 좌측 끝 → 우측 끝 → 정중앙 순으로 능청스럽게 이동한다.
  double _eyeRollShift() {
    final maxShift = width * kFidgetEyeRollMax;
    final t = _fidgetElapsed;
    const side = kFidgetEyeRollSidePhase;

    if (t < side) {
      // 정중앙 → 좌측 끝.
      return lerpDouble(0, -maxShift, t / side)!;
    } else if (t < side * 2) {
      // 좌측 끝 → 우측 끝.
      return lerpDouble(-maxShift, maxShift, (t - side) / side)!;
    }
    // 우측 끝 → 정중앙.
    final p = ((t - side * 2) / kFidgetEyeRollReturnPhase).clamp(0.0, 1.0);
    return lerpDouble(maxShift, 0, p)!;
  }

  /// 동작 2 — 방귀: 몸의 세로 오프셋(px, 양수=아래)을 연출 시간에 맞춰 계산한다.
  ///
  /// 웅크림(아래) → 뿅 팝업(위) → 원위치 순으로 움직인다.
  double _fartBodyOffsetY() {
    final t = _fidgetElapsed;
    const crouch = kFidgetFartCrouchPhase;
    const pop = kFidgetFartPopPhase;

    if (t < crouch) {
      // 0 → 웅크림 깊이(아래로).
      return lerpDouble(0, kFidgetFartCrouchDepth, t / crouch)!;
    } else if (t < crouch + pop) {
      // 웅크림 → 팝업 높이(위로).
      return lerpDouble(
          kFidgetFartCrouchDepth, -kFidgetFartPopHeight, (t - crouch) / pop)!;
    }
    // 팝업 → 원위치.
    final p = ((t - crouch - pop) / kFidgetFartSettlePhase).clamp(0.0, 1.0);
    return lerpDouble(-kFidgetFartPopHeight, 0, p)!;
  }

  /// 동작 2 — 방귀 먼지를 엉덩이 뒤쪽에서 한 번 방출한다.
  void _emitFartPuff() {
    // 엉덩이 = 바라보는 방향의 반대쪽, 몸 중앙보다 약간 아래.
    final butt = position + Vector2(-_facing * width * 0.35, height * 0.2);
    game.world.add(createFartPuff(butt, _facing));
  }

  // ─────────────────────────────────────────────
  // 클리어 축하 (Celebration)
  // ─────────────────────────────────────────────

  /// 스테이지 100% 정화·클리어 시 호출 — 기쁨의 무한 댄스를 시작한다.
  ///
  /// 게임([PongPongGame.onStageClear])이 호출한다. 상태를 [PlayerState.celebrating]
  /// 으로 바꿔 키 입력을 막고, 현재 착지 y를 축하 점프의 기준 바닥으로 굳힌다.
  void startCelebration() {
    if (state == PlayerState.celebrating) return;
    state = PlayerState.celebrating;
    _cancelFidget(); // 진행 중이던 딴짓이 있으면 즉시 정리.
    _horizontalDirection = 0;
    _celebrationBaseY = position.y;
    // 곧바로 첫 점프 — 도착하자마자 기쁨에 퐁 튀어오른다.
    _velocity
      ..x = 0
      ..y = -kCelebrationJumpForce;
    _emitCelebrationDust();
  }

  /// 클리어 축하 물리 — 제자리에서 퐁퐁 높이 튀어오르는 무한 점프.
  ///
  /// 좌우 이동·발판/낙사 판정 없이 수직 운동만 처리하므로, 클리어 후
  /// 물리 충돌이나 낙사가 일어날 여지가 없다.
  void _updateCelebration(double dt) {
    // 중력 + 수직 이동만 (가로는 제자리 고정).
    _velocity.y += kGravity * dt;
    position.y += _velocity.y * dt;

    // 기준 바닥에 닿으면 다시 높이 튀어오르고 기쁨의 먼지를 뿜는다.
    if (_velocity.y > 0 && position.y >= _celebrationBaseY) {
      position.y = _celebrationBaseY;
      _velocity.y = -kCelebrationJumpForce;
      _emitCelebrationDust();
    }
  }

  /// 축하 점프 시 평소보다 풍성한 '기쁨의 분수' 먼지를 발밑에 뿜는다.
  void _emitCelebrationDust() {
    final foot = position + Vector2(0, height / 2);
    game.world.add(createCelebrationDust(foot));
  }

  // ─────────────────────────────────────────────
  // 적(EraserEnemy)과의 상호작용
  // ─────────────────────────────────────────────

  /// 낙하 중인지 — 지우개 밟기(Stomp) 판정에 [EraserEnemy]가 참조한다.
  bool get isDescending => _velocity.y > 0;

  /// 지우개를 밟았을 때 — 살짝 통통 튀어오르고 점프를 회복한다.
  void bounceOffStomp() {
    _velocity.y = -kStompBounceForce;
    _jumpsRemaining = 2;
  }

  /// 지우개에 옆·아래로 부딪혔을 때 — 적 반대 방향으로 넉백되며 hit 상태가 된다.
  ///
  /// hit 동안엔 입력이 막히고 잠깐 무적이라 연속으로 맞지 않는다.
  void hitByEnemy(double enemyCenterX) {
    if (state == PlayerState.hit) return; // 이미 맞은 중 — 잠깐 무적.
    state = PlayerState.hit;
    _hitTimer = kPlayerHitDuration;
    _cancelFidget();
    // 적의 반대 방향으로 + 살짝 위로 튕겨 난다.
    final dir = position.x < enemyCenterX ? -1 : 1;
    _velocity
      ..x = dir * kKnockbackSpeedX
      ..y = -kKnockbackSpeedY;
  }

  // ─────────────────────────────────────────────
  // 비주얼 렌더링 (Render)
  // ─────────────────────────────────────────────
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 방귀 딴짓 중에는 몸 전체가 웅크렸다 뿅 튀도록 세로 오프셋을 준다.
    final bodyOffsetY =
        _fidget == FidgetType.fart ? _fartBodyOffsetY() : 0.0;

    canvas.save();
    canvas.translate(0, bodyOffsetY);
    _renderBody(canvas);
    _renderEyes(canvas);
    canvas.restore();

    // 머리 긁기 딴짓 중에는 동글동글한 손을 머리 위에 그린다.
    if (_fidget == FidgetType.headScratch) {
      _renderScratchHand(canvas);
    }
  }

  /// 둥글둥글한 라운드 사각형 몸체 — 핸드드로잉 느낌.
  void _renderBody(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      Offset.zero & Size(width, height),
      Radius.circular(width * 0.35),
    );
    // 안쪽 흰 면 + 검은 외곽선 2dp.
    canvas.drawRRect(body, _fillPaint);
    canvas.drawRRect(body, _outlinePaint);
  }

  /// 귀여운 눈 두 개 — 평소엔 바라보는 방향, 눈 굴리기 딴짓 중엔 그 연출을,
  /// 클리어 축하 중엔 행복하게 웃는 ◡ 모양을 그린다.
  void _renderEyes(Canvas canvas) {
    final eyeY = height * 0.42;
    final eyeGap = width * 0.18;

    // 클리어 축하 중 — 행복하게 웃는 ◡ 모양 눈.
    if (state == PlayerState.celebrating) {
      _renderHappyEyes(canvas, width / 2, eyeY, eyeGap);
      return;
    }

    // 지우개에 맞아 아픈 중 — 질끈 감은 'ㅡㅡ' 눈.
    if (state == PlayerState.hit) {
      _renderHurtEyes(canvas, width / 2, eyeY, eyeGap);
      return;
    }

    final eyeRadius = width * 0.07;
    // 눈 굴리기 딴짓 중이면 시선 연출 오프셋, 아니면 평소 바라보는 방향.
    final lookShift = _fidget == FidgetType.eyeRoll
        ? _eyeRollShift()
        : _facing * width * 0.06;
    final centerX = width / 2 + lookShift;
    canvas.drawCircle(Offset(centerX - eyeGap, eyeY), eyeRadius, _eyePaint);
    canvas.drawCircle(Offset(centerX + eyeGap, eyeY), eyeRadius, _eyePaint);
  }

  /// 행복하게 웃는 ◡ 모양 눈 — 아래로 볼록한 반원 호 두 개.
  void _renderHappyEyes(
    Canvas canvas,
    double centerX,
    double eyeY,
    double eyeGap,
  ) {
    final eyeSize = width * 0.16;
    for (final dir in const [-1, 1]) {
      final rect = Rect.fromCenter(
        center: Offset(centerX + dir * eyeGap, eyeY),
        width: eyeSize,
        height: eyeSize,
      );
      // startAngle 0 → sweep pi : 아래쪽 반원(◡) — 웃는 눈.
      canvas.drawArc(rect, 0, pi, false, _outlinePaint);
    }
  }

  /// 아파서 질끈 감은 눈 — 짧은 가로 선 두 개.
  void _renderHurtEyes(
    Canvas canvas,
    double centerX,
    double eyeY,
    double eyeGap,
  ) {
    final half = width * 0.08;
    for (final dir in const [-1, 1]) {
      final cx = centerX + dir * eyeGap;
      canvas.drawLine(
        Offset(cx - half, eyeY),
        Offset(cx + half, eyeY),
        _outlinePaint,
      );
    }
  }

  /// 동작 3 — 머리 긁기: 동글동글한 손을 머리 위 좌표에 그린다.
  ///
  /// 옆구리에서 슥 나옴 → 머리 위를 좌우로 슥슥 긁음 → 다시 옆구리로 숨음.
  void _renderScratchHand(Canvas canvas) {
    final t = _fidgetElapsed;
    const emerge = kFidgetScratchEmergePhase;
    const active = kFidgetScratchActivePhase;

    // 손이 머리 위에 자리잡는 목표 지점과, 옆구리에 숨는 시작 지점 (로컬 좌표).
    final restX = width * 0.6;
    final restY = -kFidgetHandRadius * 0.7;
    final hideX = width * 1.05;
    final hideY = height * 0.5;

    double handX;
    double handY;
    if (t < emerge) {
      // 옆구리 → 머리 위로 슥 등장.
      final p = t / emerge;
      handX = lerpDouble(hideX, restX, p)!;
      handY = lerpDouble(hideY, restY, p)!;
    } else if (t < emerge + active) {
      // 머리 위에서 좌우로 슥슥 긁적 (sin 진동).
      final phase =
          (t - emerge) / active * kFidgetScratchStrokes * 2 * pi;
      handX = restX + sin(phase) * kFidgetScratchAmplitude;
      handY = restY;
    } else {
      // 머리 위 → 옆구리로 숨음.
      final p = ((t - emerge - active) / kFidgetScratchRetractPhase)
          .clamp(0.0, 1.0);
      handX = lerpDouble(restX, hideX, p)!;
      handY = lerpDouble(restY, hideY, p)!;
    }

    final center = Offset(handX, handY);
    // 하얀 면 + 검은 2dp 외곽선 — 몸체와 같은 핸드드로잉 톤.
    canvas.drawCircle(center, kFidgetHandRadius, _fillPaint);
    canvas.drawCircle(center, kFidgetHandRadius, _outlinePaint);
  }
}
