import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'pong_pong_game.dart';

/// 플러터 앱 시작점 — Flame 게임 위젯을 화면 전체에 로드한다.
void main() {
  runApp(
    GameWidget<PongPongGame>(
      game: PongPongGame(),
    ),
  );
}
