// 퐁퐁 스케치 — 게임 위젯 스모크 테스트.
//
// 기본 보일러플레이트(카운터 MyApp 테스트)를 대체한다.
// 이 프로젝트는 Flame 게임이므로, GameWidget<PongPongGame>이
// 예외 없이 정상적으로 마운트·렌더되는지만 가볍게 확인한다.

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_pong_sketch/pong_pong_game.dart';

void main() {
  testWidgets('게임 위젯이 정상적으로 로드된다', (WidgetTester tester) async {
    // 게임 위젯을 빌드하고 한 프레임 진행.
    await tester.pumpWidget(
      GameWidget<PongPongGame>(game: PongPongGame()),
    );

    // 위젯 트리에 GameWidget이 한 개 존재하면 정상 마운트로 간주.
    expect(find.byType(GameWidget<PongPongGame>), findsOneWidget);
  });
}
