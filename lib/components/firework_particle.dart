import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../constants.dart';

/// 폭죽 입자의 방향·속도를 무작위로 흩뿌리기 위한 난수기.
final Random _rng = Random();

/// 정화도 마일스톤(25/50/75%) 달성 순간 터지는 일회성 파스텔 폭죽.
///
/// Flame 내장 파티클 시스템을 활용한다 — 핑크·민트·옐로우 입자가 사방(360°)
/// 으로 화려하게 퍼졌다가 중력에 이끌려 포물선을 그리며 투명해진다.
///
/// [ParticleSystemComponent]는 입자 수명이 끝나면 스스로 트리에서 제거되므로
/// 호출부는 world에 add만 하면 된다.
///
/// [position]: 폭죽이 터지는 월드 좌표.
ParticleSystemComponent createPurificationFirework(Vector2 position) {
  return ParticleSystemComponent(
    position: position,
    particle: Particle.generate(
      count: kFireworkParticleCount,
      lifespan: kFireworkLifespan,
      generator: (index) {
        // 입자마다 핑크·민트·옐로우 파스텔 팔레트를 번갈아 쓴다.
        final baseColor = kPastelPalette[index % kPastelPalette.length];
        final paint = Paint()..style = PaintingStyle.fill;

        // 사방(360°) 무작위 방향 + 무작위 속도.
        final angle = _rng.nextDouble() * 2 * pi;
        final speedMag = kFireworkMinSpeed +
            _rng.nextDouble() * (kFireworkMaxSpeed - kFireworkMinSpeed);
        final speed = Vector2(cos(angle) * speedMag, sin(angle) * speedMag);

        return AcceleratedParticle(
          speed: speed,
          // 중력으로 포물선을 그리며 떨어진다.
          acceleration: Vector2(0, kFireworkGravity),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final p = particle.progress; // 0.0 → 1.0
              // 반경은 살짝 줄고, 알파는 1 → 0 으로 페이드아웃.
              final radius = kFireworkRadius * (1 - p * 0.6);
              paint.color = baseColor.withValues(alpha: 1 - p);
              canvas.drawCircle(Offset.zero, radius, paint);
            },
          ),
        );
      },
    ),
  );
}
