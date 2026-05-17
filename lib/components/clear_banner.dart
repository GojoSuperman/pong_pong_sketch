import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/text.dart';
import 'package:flutter/widgets.dart';

import '../constants.dart';

/// 스테이지 클리어 시 화면 정중앙에 뜨는 축하 배너.
///
/// 파스텔 핑크 텍스트 + 핸드드로잉 톤의 검은 그림자로 스티커 같은 느낌을 주고,
/// 작게 시작해 탱글하게 커지는 팝업 등장 연출을 더한다.
class ClearBanner extends TextComponent {
  ClearBanner({required Vector2 position})
      : super(
          text: 'HAPPY MONG-I!',
          anchor: Anchor.center,
          position: position,
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
