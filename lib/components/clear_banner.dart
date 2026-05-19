import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/text.dart';
import 'package:flutter/widgets.dart';

import '../constants.dart';

/// 스테이지 클리어 시 화면 정중앙에 뜨는 축하 배너.
///
/// 파스텔 핑크 텍스트 + 핸드드로잉 톤의 검은 그림자로 스티커 같은 느낌을 주고,
/// 작게 시작해 탱글하게 커지는 팝업 등장 연출을 더한다.
///
/// 화면 상단 중앙(PURIFICATION HUD 바로 아래)에 고정된다 — 고정 해상도라
/// 어떤 창 크기에서도 항상 같은 자리에 보인다.
class ClearBanner extends TextComponent {
  ClearBanner()
      : super(
          text: 'HAPPY MONG-I!',
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: kPastelPink,
              shadows: [
                Shadow(color: kOutlineColor, offset: Offset(3, 3)),
              ],
            ),
          ),
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 상단 중앙 — PURIFICATION HUD 바로 아래에 고정. 몽이는 이 아래 공간에서
    // 가려지지 않고 춤춘다. 고정 해상도라 좌표가 흔들리지 않는다.
    position = Vector2(kGameWidth / 2, kClearBannerY);

    // 작게 시작해 탱글하게 튀어나오는 팝업 등장 연출.
    scale = Vector2.zero();
    add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.55, curve: Curves.elasticOut),
      ),
    );
  }
}
