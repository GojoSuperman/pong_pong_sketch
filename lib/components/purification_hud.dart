import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/text.dart';
import 'package:flutter/widgets.dart';

import '../constants.dart';
import '../pong_pong_game.dart';
import 'platform.dart';

/// 게이지 바와 퍼센트 숫자 사이 간격 (px).
const double _kBarGap = 8.0;

/// 퍼센트 숫자가 차지하는 가로 공간 (px).
const double _kPercentSlot = 42.0;

/// 컬러 복원 HUD — 화면 상단 중앙에 고정되는 정화도(Purification %) 표시기.
///
/// 몽이가 밟아 colored 상태가 된 발판의 비율을 실시간 계산해, '✨ 정화도'
/// 라벨 + 파스텔 그라데이션 프로그레스 바 + 퍼센트 숫자로 보여준다.
/// 카메라가 위로 스크롤돼도 항상 같은 자리에 보이도록 [PongPongGame]의
/// camera.viewport에 붙인다.
///
/// 25/50/75/100% 임계값을 넘으면 HUD가 탱글하게 펄스하고, [onMilestone]
/// 콜백으로 외부(게임)에 알린다 — 2단계 단계별 축하 연출의 확장 지점.
class PurificationHud extends PositionComponent
    with HasGameReference<PongPongGame> {
  PurificationHud({this.onMilestone})
      : super(
          size: Vector2(kHudWidth, kHudHeight),
          anchor: Anchor.topCenter,
        );

  /// 정화도 마일스톤(25/50/75/100%) 달성 시 호출되는 콜백.
  ///
  /// 인자는 달성한 퍼센트(25/50/75/100). 폭죽·무지개 등 글로벌 연출을
  /// 게임이 이 훅에 연결한다.
  final void Function(int milestonePercent)? onMilestone;

  /// 실제 정화도(0~1) — colored 발판 / 전체 발판. 마일스톤 판정의 기준값.
  double _targetRatio = 0;

  /// 화면에 표시되는 정화도(0~1) — [_targetRatio]로 부드럽게 수렴한다.
  double _displayedRatio = 0;

  /// 다음으로 발동할 마일스톤 인덱스 ([kPurificationMilestones] 기준).
  int _nextMilestoneIndex = 0;

  /// 외부에서 읽는 현재 정화도(0~1) — 글로벌 정화 연출 등이 참조한다.
  double get purificationRatio => _targetRatio;

  // ── 렌더용 Paint ──
  final Paint _trackPaint = Paint()
    ..color = kHudTrackColor
    ..style = PaintingStyle.fill;

  final Paint _outlinePaint = Paint()
    ..color = kOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kOutlineWidth;

  /// 파스텔 팔레트(핑크→민트→옐로우) 그라데이션 채움 Paint.
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  // ── 텍스트 렌더러 ──
  final TextPaint _labelPainter = TextPaint(
    style: const TextStyle(
      fontSize: kHudLabelFontSize,
      fontWeight: FontWeight.w700,
      color: kOutlineColor,
      letterSpacing: 1.6,
    ),
  );

  final TextPaint _percentPainter = TextPaint(
    style: const TextStyle(
      fontSize: kHudPercentFontSize,
      fontWeight: FontWeight.w800,
      color: kOutlineColor,
    ),
  );

  /// 게이지 바 좌측 끝 x (로컬 좌표) — 바 + 퍼센트를 묶어 가운데 정렬한다.
  double get _barLeft =>
      (kHudWidth - kHudBarWidth - _kBarGap - _kPercentSlot) / 2;

  /// 게이지 바 윗변 y (로컬 좌표).
  double get _barTop => kHudHeight - kHudBarHeight - 6;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // 핑크→민트→옐로우가 바 전체 폭에 걸쳐 흐르는 가로 그라데이션.
    // 채움 폭이 줄어도 색 위치가 고정돼, 모은 에너지가 융합되는 느낌을 준다.
    _fillPaint.shader = const LinearGradient(
      colors: [kPastelPink, kPastelMint, kPastelYellow],
    ).createShader(
      Rect.fromLTWH(_barLeft, _barTop, kHudBarWidth, kHudBarHeight),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 1) 실제 정화도 = colored 발판 수 / 전체 발판 수.
    _targetRatio = _computePurificationRatio();

    // 2) 표시 정화도를 실제 값으로 부드럽게 수렴시킨다.
    final t = (kHudFillLerpSpeed * dt).clamp(0.0, 1.0);
    _displayedRatio += (_targetRatio - _displayedRatio) * t;

    // 3) 마일스톤(25/50/75/100%) 통과 판정.
    _checkMilestones();
  }

  /// colored 상태인 발판의 비율(0~1)을 실시간 계산한다.
  ///
  /// 전체 발판은 world 트리 어디에 있든 [descendants]로 훑는다.
  /// 발판이 아직 없으면(로드 전) 0을 돌려 0으로 나눔을 피한다.
  double _computePurificationRatio() {
    var total = 0;
    var colored = 0;
    for (final platform in game.world.descendants().whereType<Platform>()) {
      total++;
      if (platform.type == PlatformType.colored) colored++;
    }
    return total == 0 ? 0 : colored / total;
  }

  /// 정화도가 임계값을 넘으면 발동하고, 낙사 리셋으로 떨어지면 재발동을 허용한다.
  void _checkMilestones() {
    // 정화도가 떨어졌으면(리셋) 인덱스를 되돌려 다음에 다시 발동되게 한다.
    while (_nextMilestoneIndex > 0 &&
        _targetRatio < kPurificationMilestones[_nextMilestoneIndex - 1]) {
      _nextMilestoneIndex--;
    }
    // 다음 임계값 이상이면 발동하고 인덱스를 전진한다.
    while (_nextMilestoneIndex < kPurificationMilestones.length &&
        _targetRatio >= kPurificationMilestones[_nextMilestoneIndex]) {
      final percent =
          (kPurificationMilestones[_nextMilestoneIndex] * 100).round();
      _reachMilestone(percent);
      _nextMilestoneIndex++;
    }
  }

  /// 마일스톤 1건 달성 처리 — HUD 자체 펄스 + 외부 콜백 통지.
  void _reachMilestone(int percent) {
    // HUD 자체 피드백 — 탱글하게 부풀었다 돌아온다.
    add(ScaleEffect.to(
      Vector2.all(kHudMilestonePulseScale),
      EffectController(
        duration: kHudMilestonePulseDuration,
        reverseDuration: kHudMilestonePulseDuration,
      ),
    ));
    // 외부 확장 지점 — 폭죽·무지개 등 글로벌 연출(2단계)을 게임이 훅한다.
    onMilestone?.call(percent);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderLabel(canvas);
    _renderBar(canvas);
    _renderPercent(canvas);
  }

  /// 'PURIFICATION' 라벨 — 게이지 바 위 중앙.
  ///
  /// 웹 환경 한글/이모지 폰트 누락(Tofu)을 원천 차단하기 위해 영문 대문자를 쓴다.
  void _renderLabel(Canvas canvas) {
    _labelPainter.render(
      canvas,
      'PURIFICATION',
      Vector2(kHudWidth / 2, 5),
      anchor: Anchor.topCenter,
    );
  }

  /// 정화도 게이지 — 흰 트랙 + 파스텔 그라데이션 채움 + 검은 2dp 외곽선.
  void _renderBar(Canvas canvas) {
    const radius = Radius.circular(kHudBarRadius);
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(_barLeft, _barTop, kHudBarWidth, kHudBarHeight),
      radius,
    );

    // 1) 트랙(빈 게이지) — 흰 면.
    canvas.drawRRect(track, _trackPaint);

    // 2) 표시 정화도만큼 그라데이션 채움 — 트랙 둥근 모서리 안으로 클립.
    final ratio = _displayedRatio.clamp(0.0, 1.0);
    if (ratio > 0.001) {
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTWH(_barLeft, _barTop, kHudBarWidth * ratio, kHudBarHeight),
        radius,
      );
      canvas.save();
      canvas.clipRRect(track);
      canvas.drawRRect(fill, _fillPaint);
      canvas.restore();
    }

    // 3) 검은 2dp 외곽선 — 채움 위에 덮어 스케치북 테두리를 유지.
    canvas.drawRRect(track, _outlinePaint);
  }

  /// 퍼센트 숫자 — 게이지 바 오른쪽에 세로 중앙 정렬.
  void _renderPercent(Canvas canvas) {
    final percent = (_displayedRatio.clamp(0.0, 1.0) * 100).round();
    _percentPainter.render(
      canvas,
      '$percent%',
      Vector2(_barLeft + kHudBarWidth + _kBarGap, _barTop + kHudBarHeight / 2),
      anchor: Anchor.centerLeft,
    );
  }
}
