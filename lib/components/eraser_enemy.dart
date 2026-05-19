import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../constants.dart';
import '../helpers/audio_manager.dart';
import '../pong_pong_game.dart';
import 'platform.dart';
import 'player.dart';

/// 지우개 군단 — 스테이지 4 '습격당한 낙서장'의 적.
///
/// 자신이 배치된 발판을 좌우로 순찰하며, 그 발판이 colored면 계속 monochrome
/// 으로 지워 정화도를 실시간으로 깎는다. 몽이가 위에서 밟으면 지우개 가루를
/// 터뜨리며 사라지고, 옆·아래에서 부딪히면 몽이를 넉백시킨다.
class EraserEnemy extends PositionComponent
    with CollisionCallbacks, HasGameReference<PongPongGame> {
  EraserEnemy({required this.platform})
      : super(
          size: Vector2(kEraserWidth, kEraserHeight),
          anchor: Anchor.topLeft,
        );

  /// 순찰·지우기 대상 발판.
  final Platform platform;

  /// 순찰 방향 (1=오른쪽, -1=왼쪽).
  int _direction = 1;

  // ── 렌더용 Paint (매 프레임 재생성 방지) ──
  final Paint _bodyPaint = Paint()
    ..color = kEraserBodyColor
    ..style = PaintingStyle.fill;
  final Paint _bandPaint = Paint()
    ..color = kEraserBandColor
    ..style = PaintingStyle.fill;
  final Paint _outlinePaint = Paint()
    ..color = kOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kOutlineWidth;
  final Paint _eyePaint = Paint()
    ..color = kOutlineColor
    ..style = PaintingStyle.fill;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // 발판 가운데 윗면에 올라서도록 배치.
    position = Vector2(
      platform.position.x + (platform.size.x - width) / 2,
      platform.position.y - height,
    );
    // 몽이와의 충돌 감지를 위한 히트박스.
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 1) 발판 색을 계속 지운다 — colored면 monochrome으로 강제 초기화.
    //    HUD가 매 프레임 colored 비율을 재계산하므로 정화도가 실시간 감소한다.
    if (platform.type == PlatformType.colored) {
      platform.resetToMonochrome();
    }

    // 2) 순찰 — 발판 좌우 끝에서 방향을 뒤집어 떨어지지 않게 왕복한다.
    position.x += _direction * kEraserSpeed * dt;
    final patrolLeft = platform.position.x;
    final patrolRight = platform.position.x + platform.size.x - width;
    if (position.x <= patrolLeft) {
      position.x = patrolLeft;
      _direction = 1;
    } else if (position.x >= patrolRight) {
      position.x = patrolRight;
      _direction = -1;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! Player) return;
    final player = other;

    // 스톰프 판정 — 몽이가 낙하 중이고 발 끝이 지우개 몸 위쪽에 들어왔으면 밟은 것.
    final playerFoot = player.position.y + player.height / 2;
    final enemyMiddle = position.y + height / 2;
    if (player.isDescending && playerFoot < enemyMiddle) {
      // 밟혔다 — 지우개 가루를 터뜨리며 사라지고, 몽이는 통통 튀어오른다.
      AudioManager.playStomp();
      game.world.add(createEraserCrumbs(position + size / 2));
      removeFromParent();
      player.bounceOffStomp();
    } else {
      // 옆·아래 충돌 — 몽이를 적 반대 방향으로 넉백시킨다.
      player.hitByEnemy(position.x + width / 2);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // 지우개 몸통 — 모서리가 살짝 둥근 사각형.
    final body = RRect.fromRectAndRadius(
      Offset.zero & Size(width, height),
      const Radius.circular(5),
    );
    canvas.drawRRect(body, _bodyPaint);
    // 가운데 띠 — 투톤 지우개 느낌.
    canvas.drawRect(
      Rect.fromLTWH(0, height * 0.54, width, height * 0.24),
      _bandPaint,
    );
    canvas.drawRRect(body, _outlinePaint);
    // 작은 눈 두 개 — 순찰 방향을 흘끔 본다.
    final eyeY = height * 0.30;
    final eyeR = width * 0.085;
    final gaze = _direction * width * 0.05;
    canvas.drawCircle(Offset(width * 0.37 + gaze, eyeY), eyeR, _eyePaint);
    canvas.drawCircle(Offset(width * 0.63 + gaze, eyeY), eyeR, _eyePaint);
  }
}

/// 지우개가 밟혀 사라질 때 사방으로 터지는 '지우개 가루' 파티클.
///
/// 작은 사각 조각들이 360°로 흩어져 중력에 떨어지며 투명해진다.
ParticleSystemComponent createEraserCrumbs(Vector2 position) {
  final rng = Random();
  return ParticleSystemComponent(
    position: position,
    particle: Particle.generate(
      count: kEraserCrumbCount,
      lifespan: kEraserCrumbLifespan,
      generator: (index) {
        final paint = Paint()..style = PaintingStyle.fill;
        final angle = rng.nextDouble() * 2 * pi;
        final speed = 70 + rng.nextDouble() * 130;
        return AcceleratedParticle(
          speed: Vector2(cos(angle) * speed, sin(angle) * speed),
          acceleration: Vector2(0, 280),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final p = particle.progress; // 0.0 → 1.0
              final s = kEraserCrumbSize * (1 - p * 0.5);
              paint.color = kEraserBodyColor.withValues(alpha: 1 - p);
              // 가루는 작은 사각 조각으로.
              canvas.drawRect(
                Rect.fromCenter(center: Offset.zero, width: s, height: s),
                paint,
              );
            },
          ),
        );
      },
    ),
  );
}
