import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../constants.dart';

/// 먼지 입자의 방향·속도·시작 위치를 무작위로 흩뿌리기 위한 난수기.
final Random _rng = Random();

/// 몽이가 점프하는 순간 발밑에서 '퐁' 터지는 파스텔 먼지 구름을 만든다.
///
/// Flame 내장 파티클 시스템([ParticleSystemComponent])을 그대로 활용한다 —
/// 민트·인디핑크 반투명 동그라미들이 외곽선 없이 바깥·위로 몽실몽실
/// 퍼지다 투명해지며(Fade Out) 사라진다.
///
/// [ParticleSystemComponent]는 입자 수명이 끝나면 스스로 트리에서 제거되므로
/// 호출부는 world에 add만 하면 되고 별도 정리가 필요 없다.
///
/// [footPosition]: 몽이의 발밑 월드 좌표 — 먼지가 피어오를 기준점.
ParticleSystemComponent createJumpDust(Vector2 footPosition) {
  return ParticleSystemComponent(
    position: footPosition,
    particle: Particle.generate(
      count: kDustParticleCount,
      lifespan: kDustLifespan,
      generator: _buildDustParticle,
    ),
  );
}

/// 클리어 축하 점프 시 — 평소 점프 먼지([createJumpDust])보다
/// [kCelebrationDustMultiplier]배 풍성한 '기쁨의 분수' 먼지 구름.
///
/// 입자 수만 늘릴 뿐 핑크·민트 믹스 연출은 점프 먼지와 똑같이 재사용한다.
ParticleSystemComponent createCelebrationDust(Vector2 footPosition) {
  return ParticleSystemComponent(
    position: footPosition,
    particle: Particle.generate(
      count: kDustParticleCount * kCelebrationDustMultiplier,
      lifespan: kDustLifespan,
      generator: _buildDustParticle,
    ),
  );
}

/// 먼지 입자 하나를 만든다 — 민트·인디핑크를 번갈아, 위쪽으로 몽실 퍼진다.
///
/// [createJumpDust]와 [createCelebrationDust]가 공유하는 입자 생성기.
Particle _buildDustParticle(int index) {
  // 입자마다 민트·인디핑크를 번갈아 — 외곽선 없는 소프트 원.
  // 발판 팔레트보다 한 톤 진한 먼지 전용 색을 쓴다.
  final baseColor = index.isEven ? kDustMint : kDustPink;
  // 입자별 Paint는 한 번만 생성하고, 렌더 시 알파만 갱신한다.
  final paint = Paint()..style = PaintingStyle.fill;

  // 위쪽 반구(−180°~0°) 방향으로 퍼지는 속도 벡터.
  final angle = -pi + _rng.nextDouble() * pi;
  final speedMag = kDustRiseSpeed * (0.4 + _rng.nextDouble() * 0.6);
  final speed = Vector2(cos(angle) * speedMag, sin(angle) * speedMag);

  // 발밑에서 살짝 좌우로 흩어진 시작 지점.
  final startOffset = Vector2(
    (_rng.nextDouble() - 0.5) * kDustMaxRadius * 2,
    0,
  );

  return AcceleratedParticle(
    position: startOffset,
    speed: speed,
    // 중력으로 살짝 가라앉으며 자연스럽게 사그라든다.
    acceleration: Vector2(0, kDustGravity),
    child: ComputedParticle(
      renderer: (canvas, particle) {
        final p = particle.progress; // 0.0 → 1.0
        // 반경: 작게 시작해 몽실 커진다.
        final radius = lerpDouble(kDustMinRadius, kDustMaxRadius, p)!;
        // 알파: 시작 알파에서 0으로 페이드아웃.
        final alpha = (1.0 - p) * kDustStartAlpha;
        paint.color = baseColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset.zero, radius, paint);
      },
    ),
  );
}

/// 몽이가 idle 딴짓 '방귀'를 뀔 때 엉덩이 뒤에서 뿜어져 나오는 작은 핑크 먼지.
///
/// 점프 먼지([createJumpDust])보다 훨씬 작고 적은 1~2개 입자가, 바라보는
/// 방향의 반대쪽(엉덩이 뒤)으로 살짝 흩어졌다 투명해지며 사라진다.
///
/// [emitPosition]: 엉덩이 월드 좌표 — 먼지가 뿜어질 기준점.
/// [facing]: 몽이가 바라보는 방향(1=오른쪽, -1=왼쪽) — 먼지는 그 반대로 뿜는다.
ParticleSystemComponent createFartPuff(Vector2 emitPosition, int facing) {
  return ParticleSystemComponent(
    position: emitPosition,
    particle: Particle.generate(
      count: kFartPuffCount,
      lifespan: kFartPuffLifespan,
      generator: (index) {
        final paint = Paint()..style = PaintingStyle.fill;

        // 바라보는 방향의 반대쪽 + 살짝 위로 흩어진다.
        final speed = Vector2(
          -facing * (18 + _rng.nextDouble() * 24),
          -8 - _rng.nextDouble() * 18,
        );
        final startOffset = Vector2(
          (_rng.nextDouble() - 0.5) * 6,
          (_rng.nextDouble() - 0.5) * 6,
        );

        return AcceleratedParticle(
          position: startOffset,
          speed: speed,
          // 점프 먼지보다 약한 중력으로 살며시 가라앉는다.
          acceleration: Vector2(0, kDustGravity * 0.35),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final p = particle.progress;
              final radius =
                  lerpDouble(kFartPuffMinRadius, kFartPuffMaxRadius, p)!;
              final alpha = (1.0 - p) * kDustStartAlpha;
              // 요구 사양대로 파스텔 핑크(#FFB3C6).
              paint.color = kPastelPink.withValues(alpha: alpha);
              canvas.drawCircle(Offset.zero, radius, paint);
            },
          ),
        );
      },
    ),
  );
}
