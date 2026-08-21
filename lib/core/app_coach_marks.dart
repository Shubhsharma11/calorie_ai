import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/coach_mark_tooltip.dart';

class CoachMarkStep {
  CoachMarkStep({
    required this.key,
    required this.title,
    required this.description,
    this.preferTooltipAbove = true,
    this.holePadding = 2,
    this.holePaddingBottom,
    this.holeShiftY = 0,
    this.holeRadius = 14,
  });

  final GlobalKey key;
  final LayerLink link = LayerLink();
  final String title;
  final String description;
  final bool preferTooltipAbove;
  final double holePadding;
  /// When set, overrides [holePadding] on the bottom edge only.
  final double? holePaddingBottom;
  /// Shifts the whole hole down (positive) or up (negative).
  final double holeShiftY;
  final double holeRadius;

  Rect inflateHole(Rect target) {
    final bottom = holePaddingBottom ?? holePadding;
    final dy = holeShiftY;
    return Rect.fromLTRB(
      target.left - holePadding,
      target.top - holePadding + dy,
      target.right + holePadding,
      target.bottom + bottom + dy,
    );
  }
}

/// First-launch feature tour using a custom [Overlay] (no showcaseview).
abstract final class AppCoachMarks {
  static final searchKey = GlobalKey(debugLabel: 'coach_search');
  static final calorieKey = GlobalKey(debugLabel: 'coach_calorie');
  static final addFoodKey = GlobalKey(debugLabel: 'coach_add_food');
  static final waterKey = GlobalKey(debugLabel: 'coach_water');
  static final weightKey = GlobalKey(debugLabel: 'coach_weight');
  static final diaryNavKey = GlobalKey(debugLabel: 'coach_diary');
  static final scanNavKey = GlobalKey(debugLabel: 'coach_scan');
  static final statsNavKey = GlobalKey(debugLabel: 'coach_stats');
  static final profileNavKey = GlobalKey(debugLabel: 'coach_profile');
  static final addFoodAllKey = GlobalKey(debugLabel: 'coach_add_food_all');
  static final addFoodMyMealsKey =
      GlobalKey(debugLabel: 'coach_add_food_my_meals');
  static final addFoodMyFoodKey =
      GlobalKey(debugLabel: 'coach_add_food_my_food');
  static final addFoodFavouriteKey =
      GlobalKey(debugLabel: 'coach_add_food_favourite');
  static final addFoodSearchKey =
      GlobalKey(debugLabel: 'coach_add_food_search');

  static final steps = <CoachMarkStep>[
    CoachMarkStep(
      key: searchKey,
      title: 'Find food fast',
      description:
          'Search any dish from Home and log it in seconds.',
      preferTooltipAbove: false,
    ),
    CoachMarkStep(
      key: calorieKey,
      title: 'Your day at a glance',
      description:
          'Calories left, macros, and today’s progress — all here.',
      // Frame the overview block (card edges through macros).
      // Nudge the whole border a little downward.
      preferTooltipAbove: false,
      holePadding: 0,
      holePaddingBottom: 0,
      holeShiftY: 8, // nudged in _placeTip via measured meal CTA on devices
      holeRadius: 20,
    ),
    CoachMarkStep(
      key: addFoodKey,
      title: 'Log every meal',
      description:
          'Tap to add foods, custom items, or meals you saved.',
      preferTooltipAbove: false,
      holePadding: 0,
      holeRadius: 16,
    ),
    CoachMarkStep(
      key: waterKey,
      title: 'Sip and track',
      description:
          'Tap + for a glass, or open the card for your full day.',
      preferTooltipAbove: false,
      holePadding: 2,
      holeRadius: 18,
    ),
    CoachMarkStep(
      key: weightKey,
      title: 'Watch the scale',
      description:
          'Log weigh-ins and see how close you are to your goal.',
      preferTooltipAbove: false,
      holePadding: 2,
      holeRadius: 24,
    ),
    CoachMarkStep(
      key: diaryNavKey,
      title: 'Your food diary',
      description:
          'Browse meals by day and tweak anything you logged.',
      holePadding: 4,
      holeRadius: 12,
    ),
    CoachMarkStep(
      key: scanNavKey,
      title: 'Scan the label',
      description:
          'Point at a barcode — nutrition fills in for you.',
      holePadding: 4,
      holeRadius: 28,
    ),
    CoachMarkStep(
      key: statsNavKey,
      title: 'Spot your trends',
      description:
          'See patterns in calories, water, weight, and more.',
      holePadding: 4,
      holeRadius: 12,
    ),
    CoachMarkStep(
      key: profileNavKey,
      title: 'Make it yours',
      description:
          'Goals, personal details, and settings live here.',
      holePadding: 4,
      holeRadius: 12,
    ),
  ];

  /// First visit to Add Food / Search — All, My Meals, My Food, Favourite.
  static final addFoodSteps = <CoachMarkStep>[
    CoachMarkStep(
      key: addFoodAllKey,
      title: 'All your recents',
      description:
          'Foods you logged lately — tap one to add it again.',
      preferTooltipAbove: false,
      holePadding: 4,
      holeRadius: 20,
    ),
    CoachMarkStep(
      key: addFoodMyMealsKey,
      title: 'My Meals',
      description:
          'Meals you built yourself, ready to log in one tap.',
      preferTooltipAbove: false,
      holePadding: 4,
      holeRadius: 20,
    ),
    CoachMarkStep(
      key: addFoodMyFoodKey,
      title: 'My Food',
      description:
          'Custom foods you created, with nutrition you set.',
      preferTooltipAbove: false,
      holePadding: 4,
      holeRadius: 20,
    ),
    CoachMarkStep(
      key: addFoodFavouriteKey,
      title: 'Favourites',
      description:
          'Star a food or meal to keep it here for next time.',
      preferTooltipAbove: false,
      holePadding: 4,
      holeRadius: 20,
    ),
    CoachMarkStep(
      key: addFoodSearchKey,
      title: 'Tap to search',
      description:
          'Type any dish here and log it in seconds.',
      preferTooltipAbove: false,
      holePadding: 6,
      holeRadius: 16,
    ),
  ];

  static List<GlobalKey?> get navKeys => [
        null,
        diaryNavKey,
        scanNavKey,
        statsNavKey,
        profileNavKey,
      ];

  static Future<void> Function()? replayHandler;

  static Widget target({
    required GlobalKey key,
    required Widget child,
  }) {
    CoachMarkStep? step;
    for (final s in [...steps, ...addFoodSteps]) {
      if (s.key == key) {
        step = s;
        break;
      }
    }
    final keyed = KeyedSubtree(key: key, child: child);
    if (step == null) return keyed;
    return CompositedTransformTarget(link: step.link, child: keyed);
  }

  static Future<void> markSeen(LocalStorageService storage) async {
    await storage.saveCoachMarksSeen(seen: true);
  }

  static Future<bool> shouldShow(LocalStorageService storage) async {
    return !(await storage.isCoachMarksSeen());
  }

  static Future<void> replay(LocalStorageService storage) async {
    await storage.saveCoachMarksSeen(seen: false);
    await storage.saveAddFoodCoachMarksSeen(seen: false);
    final handler = replayHandler;
    if (handler != null) await handler();
  }

  static Future<void> markAddFoodSeen(LocalStorageService storage) async {
    await storage.saveAddFoodCoachMarksSeen(seen: true);
  }

  static Future<bool> shouldShowAddFood(LocalStorageService storage) async {
    // Wait until the Home tour is done so the two overlays never overlap.
    if (!(await storage.isCoachMarksSeen())) return false;
    return !(await storage.isAddFoodCoachMarksSeen());
  }
}

class CoachMarkHost extends StatefulWidget {
  const CoachMarkHost({
    super.key,
    required this.child,
    required this.storage,
    required this.onFinished,
    this.steps,
    this.shouldShow,
    this.markSeen,
    this.onPresentingStep,
    this.onCompleted,
    this.bindReplayHandler = true,
  });

  final Widget child;
  final LocalStorageService storage;
  final VoidCallback onFinished;
  final List<CoachMarkStep>? steps;
  final Future<bool> Function(LocalStorageService storage)? shouldShow;
  final Future<void> Function(LocalStorageService storage)? markSeen;
  final ValueChanged<int>? onPresentingStep;
  final VoidCallback? onCompleted;
  final bool bindReplayHandler;

  @override
  State<CoachMarkHost> createState() => _CoachMarkHostState();
}

class _CoachMarkHostState extends State<CoachMarkHost> {
  OverlayEntry? _entry;
  int _step = 0;
  int _displayStep = 0;
  bool _active = false;
  bool _starting = false;
  bool _busy = false;
  bool _ready = false;

  List<CoachMarkStep> get _steps => widget.steps ?? AppCoachMarks.steps;

  @override
  void initState() {
    super.initState();
    if (widget.bindReplayHandler) {
      AppCoachMarks.replayHandler = _replay;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void dispose() {
    if (widget.bindReplayHandler && AppCoachMarks.replayHandler == _replay) {
      AppCoachMarks.replayHandler = null;
    }
    _removeOverlay();
    super.dispose();
  }

  Future<void> _replay() async {
    if (!mounted) return;
    _removeOverlay();
    _active = false;
    _busy = false;
    _ready = false;
    _step = 0;
    _displayStep = 0;
    await widget.storage.saveCoachMarksSeen(seen: false);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    _startAt(0);
  }

  Future<void> _maybeStart() async {
    if (!mounted || _starting || _active) return;
    _starting = true;
    final shouldShow = widget.shouldShow ?? AppCoachMarks.shouldShow;
    final show = await shouldShow(widget.storage);
    if (!mounted) return;
    if (!show) {
      _starting = false;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _startAt(0);
    _starting = false;
  }

  void _startAt(int index) {
    _step = index;
    _displayStep = index;
    _active = true;
    unawaited(_presentStep(isFirst: true));
  }

  Future<void> _prepareStep(int index) async {
    widget.onPresentingStep?.call(index);
    if (widget.onPresentingStep == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_active) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !_active) return;
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _presentStep({bool isFirst = false}) async {
    if (!mounted || !_active || _busy) return;
    _busy = true;
    try {
      await _prepareStep(_step);
      if (!mounted || !_active) return;

      if (isFirst) {
        await _ensureStepVisible(_step);
        if (!mounted || !_active) return;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !_active) return;
        if (!_targetOk(_step)) {
          await _skipMissingTargets();
          return;
        }
        _displayStep = _step;
        _ready = true;
        _insertOrRebuildOverlay();
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !_active) return;
        _insertOrRebuildOverlay();
        return;
      }

      // Switch tip + spotlight together, then scroll while they animate.
      if (!_targetOk(_step)) {
        await _ensureStepVisible(_step);
        if (!mounted || !_active) return;
        await WidgetsBinding.instance.endOfFrame;
        if (!_targetOk(_step)) {
          await _skipMissingTargets();
          return;
        }
      }

      _displayStep = _step;
      _ready = true;
      _insertOrRebuildOverlay();

      // Scroll in parallel with the spotlight/tip motion.
      await Future.wait<void>([
        _ensureStepVisible(_step),
        Future<void>.delayed(const Duration(milliseconds: 720)),
      ]);
      if (!mounted || !_active) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_active) return;
      _insertOrRebuildOverlay();
    } finally {
      _busy = false;
    }
  }

  bool _targetOk(int index) {
    if (index < 0 || index >= _steps.length) return false;
    final step = _steps[index];
    final rect = _readRect(step.key);
    return rect != null && rect.height >= 4 && rect.width >= 4;
  }

  Future<void> _skipMissingTargets() async {
    if (_step + 1 < _steps.length) {
      _step += 1;
      _busy = false;
      await _presentStep();
      return;
    }
    await _finish(skipped: true);
  }

  void _insertOrRebuildOverlay() {
    if (_steps.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    if (_entry == null) {
      _entry = OverlayEntry(builder: (context) {
        final i = _displayStep.clamp(0, math.max(0, _steps.length - 1)).toInt();
        return _CoachMarkLayer(
          key: const ValueKey('coach_mark_layer'),
          stepIndex: i,
          stepCount: _steps.length,
          step: _steps[i],
          ready: _ready,
          canAdvance: _ready && (!_busy || _displayStep == _step),
          onSkip: _skipTour,
          onNext: _next,
        );
      });
      overlay.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  Rect? _readRect(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _ensureStepVisible(int index) async {
    if (index < 0 || index >= _steps.length) return;
    final step = _steps[index];
    final ctx = step.key.currentContext;
    if (ctx == null) return;
    try {
      // Leave room for the tip on the preferred side of the target.
      final double alignment;
      if (step.key == AppCoachMarks.addFoodKey) {
        // Tip below → keep CTA higher so tip clears water card / nav.
        alignment = 0.28;
      } else if (step.key == AppCoachMarks.weightKey) {
        // Tip below with extra gap → keep card higher so tip clears the nav.
        alignment = 0.22;
      } else if (step.key == AppCoachMarks.waterKey) {
        // Tip below → keep water card higher so tip fits under it.
        alignment = 0.30;
      } else if (step.key == AppCoachMarks.calorieKey) {
        // Tip under meal CTA → keep overview high; tune by screen height.
        final h = MediaQuery.maybeOf(ctx)?.size.height ?? 800;
        alignment = h < 700 ? 0.12 : (h > 900 ? 0.20 : 0.16);
      } else {
        final h = MediaQuery.maybeOf(ctx)?.size.height ?? 800;
        alignment = h < 700 ? 0.42 : 0.36;
      }
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 620),
        curve: const Cubic(0.22, 0.61, 0.36, 1),
        alignment: alignment,
      );
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {}
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  void _next() {
    if (!_active || !_ready) return;
    // Block only while the overlay hasn't caught up to [_step] yet.
    // After [_displayStep] updates, allow Continue even during scroll polish.
    if (_busy && _displayStep != _step) return;
    final next = _step + 1;
    if (next >= _steps.length) {
      unawaited(_finish(skipped: false));
      return;
    }
    HapticFeedback.selectionClick();
    _step = next;
    unawaited(_presentStep());
  }

  void _skipTour() {
    unawaited(_finish(skipped: true));
  }

  Future<void> _finish({bool skipped = false}) async {
    if (!_active) return;
    _active = false;
    _ready = false;
    _insertOrRebuildOverlay();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _removeOverlay();
    final markSeen = widget.markSeen ?? AppCoachMarks.markSeen;
    await markSeen(widget.storage);
    widget.onFinished();
    if (!skipped) widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CoachMarkLayer extends StatefulWidget {
  const _CoachMarkLayer({
    super.key,
    required this.stepIndex,
    required this.stepCount,
    required this.step,
    required this.ready,
    required this.canAdvance,
    required this.onSkip,
    required this.onNext,
  });

  final int stepIndex;
  final int stepCount;
  final CoachMarkStep step;
  final bool ready;
  final bool canAdvance;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  State<_CoachMarkLayer> createState() => _CoachMarkLayerState();
}

class _CoachMarkLayerState extends State<_CoachMarkLayer>
    with TickerProviderStateMixin {
  final GlobalKey _tipKey = GlobalKey(debugLabel: 'coach_tip_measure');
  double? _measuredTipH;

  late final AnimationController _motion;
  late final AnimationController _appear;
  late final AnimationController _arrive;

  /// Spotlight center moves slightly ahead of tip for a linked “follow” feel.
  late final CurvedAnimation _holeMove;
  late final CurvedAnimation _tipMove;
  late final CurvedAnimation _sizeMove;
  late final Animation<double> _tipLift;
  late final Animation<double> _tipFade;
  late final Animation<double> _borderPulse;
  late final CurvedAnimation _appearCurve;

  Rect? _holeFrom;
  Rect? _holeTo;
  double _tipLeftFrom = 16;
  double _tipTopFrom = 80;
  double _tipLeftTo = 16;
  double _tipTopTo = 80;
  double _tipW = 300;
  double _radiusFrom = 14;
  double _radiusTo = 14;
  int _boundStep = -1;
  bool _tracking = false;

  static const _duration = Duration(milliseconds: 680);

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: _duration);
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.ready ? 1 : 0,
    );
    _arrive = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // Hole leads; tip follows a beat later — still same step, clearer motion.
    _holeMove = CurvedAnimation(
      parent: _motion,
      curve: const Interval(0.0, 0.88, curve: Cubic(0.22, 0.61, 0.36, 1)),
    );
    _tipMove = CurvedAnimation(
      parent: _motion,
      curve: const Interval(0.10, 1.0, curve: Cubic(0.22, 0.61, 0.36, 1)),
    );
    _sizeMove = CurvedAnimation(
      parent: _motion,
      curve: const Interval(0.0, 0.95, curve: Curves.easeInOutCubic),
    );
    _tipLift = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.98, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
    ]).animate(_motion);
    _tipFade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.88)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 65,
      ),
    ]).animate(_motion);
    _borderPulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 2.5, end: 3.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 3.2, end: 2.5)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_motion);

    _appearCurve = CurvedAnimation(
      parent: _appear,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _motion.addListener(_onTick);
    _appear.addListener(_onTick);
    _arrive.addListener(_onTick);
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _arrive.forward(from: 0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTargets(animate: false);
      _measureTip();
      if (widget.ready) _appear.forward();
    });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _motion.removeListener(_onTick);
    _appear.removeListener(_onTick);
    _arrive.removeListener(_onTick);
    _holeMove.dispose();
    _tipMove.dispose();
    _sizeMove.dispose();
    _appearCurve.dispose();
    _motion.dispose();
    _appear.dispose();
    _arrive.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CoachMarkLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready) {
      if (widget.ready) {
        _appear.forward();
      } else {
        _appear.reverse();
      }
    }
    final stepChanged = oldWidget.stepIndex != widget.stepIndex;
    if (stepChanged) {
      _measuredTipH = null;
      _arrive.stop();
      _arrive.value = 0;
    }
    if (stepChanged || oldWidget.ready != widget.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncTargets(
          animate: stepChanged &&
              oldWidget.ready &&
              widget.ready &&
              _holeTo != null,
        );
        _measureTip();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _measureTip();
        });
      });
    }
  }

  void _measureTip() {
    if (!mounted) return;
    final box = _tipKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final h = box.size.height;
    if (_measuredTipH != null && (h - _measuredTipH!).abs() <= 0.5) return;
    _measuredTipH = h;

    if (_motion.isAnimating) {
      _refineDestinationOnly();
      return;
    }
    _syncTargets(animate: false);
  }

  void _refineDestinationOnly() {
    final media = MediaQuery.of(context);
    final size = media.size;
    final tipW = _tipMaxWidth(size);
    final tipH = _tipHeight(media);
    final target = _targetRect();
    if (target == null) return;
    final hole = widget.step.inflateHole(target);
    final placed = _placeTip(
      size: size,
      media: media,
      hole: hole,
      tipW: tipW,
      tipH: tipH,
    );
    _holeTo = hole;
    _tipLeftTo = placed.left;
    _tipTopTo = placed.top;
    _tipW = tipW;
    _radiusTo = widget.step.holeRadius;
    if (!_motion.isAnimating) {
      _holeFrom = hole;
      _tipLeftFrom = placed.left;
      _tipTopFrom = placed.top;
      _radiusFrom = widget.step.holeRadius;
    }
  }

  Rect? _targetRect() {
    return _readKeyRect(widget.step.key);
  }

  Rect? _readKeyRect(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.width < 4 || rect.height < 4) return null;
    return rect;
  }

  double _tipHeight(MediaQueryData media) {
    final textScale = media.textScaler.scale(1).clamp(0.85, 1.35);
    // Includes "Quick tip" eyebrow + actions; live measure overrides this.
    return _measuredTipH ?? (168.0 * textScale);
  }

  double _bottomReserve(MediaQueryData media) {
    // Floating nav + home indicator + tip clearance under tall cards.
    return media.viewPadding.bottom + 112;
  }

  double _sideInset(Size size) {
    if (size.width < 360) return 12;
    if (size.width > 600) return 24;
    return 16;
  }

  double _tipMaxWidth(Size size) {
    final inset = _sideInset(size) * 2;
    if (size.width < 360) return size.width - inset;
    if (size.width >= 600) return math.min(360.0, size.width * 0.55);
    return math.min(300.0, size.width - inset);
  }

  /// Scale helper so fallback spacing tracks phone / tablet width.
  double _layoutScale(Size size) {
    return (size.width / 390.0).clamp(0.85, 1.35);
  }

  ({double left, double top}) _placeTip({
    required Size size,
    required MediaQueryData media,
    required Rect hole,
    required double tipW,
    required double tipH,
  }) {
    final isMealCta = widget.step.key == AppCoachMarks.addFoodKey;
    final isWeight = widget.step.key == AppCoachMarks.weightKey;
    final isWater = widget.step.key == AppCoachMarks.waterKey;
    final isCalorie = widget.step.key == AppCoachMarks.calorieKey;
    final scale = _layoutScale(size);

    var gap = isMealCta
        ? 14.0 * scale
        : isWeight
            ? 22.0 * scale
            : isWater
                ? 16.0 * scale
                : 16.0 * scale;

    // Calorie tip sits just under the measured meal CTA on every device.
    Rect? mealCtaRect;
    double belowClearance = 0;
    if (isCalorie) {
      gap = -8; // sit a little higher against the meal button
      mealCtaRect = _readKeyRect(AppCoachMarks.addFoodKey);
      if (mealCtaRect != null) {
        belowClearance = math.max(0.0, mealCtaRect.bottom - hole.bottom);
      } else {
        // Fallback until the button has laid out (14 gap + ~48 button).
        belowClearance = (14 + 48) * scale;
      }
    }

    final topSafe = media.padding.top + 8;
    final bottomSafe = size.height - _bottomReserve(media);
    final side = _sideInset(size);
    final maxLeft = math.max(side, size.width - tipW - side);

    final left = (hole.center.dx - tipW / 2).clamp(side, maxLeft);

    final aboveTop = hole.top - tipH - gap;
    final belowTop = isCalorie && mealCtaRect != null
        ? mealCtaRect.bottom + gap
        : hole.bottom + gap + belowClearance;
    final preferAbove = widget.step.preferTooltipAbove;

    final fitsAbove = aboveTop >= topSafe;
    final fitsBelow = belowTop + tipH <= bottomSafe;
    final spaceAbove = hole.top - topSafe;
    final spaceBelow = bottomSafe - belowTop;

    // Obstacle used for overlap checks (includes meal CTA for calorie).
    final obstacleBottom = isCalorie && mealCtaRect != null
        ? mealCtaRect.bottom
        : hole.bottom + belowClearance;
    final obstacle = Rect.fromLTRB(
      hole.left,
      hole.top,
      hole.right,
      obstacleBottom,
    ).inflate(math.max(gap, 2));

    double top;
    if (preferAbove && fitsAbove) {
      top = aboveTop;
    } else if (!preferAbove && fitsBelow) {
      top = belowTop;
    } else if (fitsAbove && fitsBelow) {
      top = preferAbove ? aboveTop : belowTop;
    } else if (fitsAbove) {
      top = aboveTop;
    } else if (fitsBelow) {
      top = belowTop;
    } else if (preferAbove && spaceAbove >= tipH * 0.55) {
      // Not enough for full tip — pin under safe top but keep clear of hole.
      top = math.min(topSafe, hole.top - tipH - gap);
      if (top < topSafe) top = topSafe;
      // If that still collides, flip below when possible.
      if (Rect.fromLTWH(left, top, tipW, tipH).overlaps(obstacle) &&
          fitsBelow) {
        top = belowTop;
      }
    } else if (spaceBelow >= spaceAbove && fitsBelow) {
      top = belowTop;
    } else if (fitsAbove) {
      top = aboveTop;
    } else {
      // Last resort: place on the side with more free room, never covering hole center.
      if (spaceAbove >= spaceBelow) {
        top = topSafe;
        if (top + tipH > hole.top - gap && fitsBelow) {
          top = belowTop;
        }
      } else {
        top = bottomSafe - tipH;
        if (top < belowTop && fitsAbove) {
          top = aboveTop;
        }
      }
    }

    var tipRect = Rect.fromLTWH(left, top, tipW, tipH);
    if (tipRect.overlaps(obstacle)) {
      if (preferAbove && fitsBelow) {
        top = belowTop;
      } else if (!preferAbove && fitsAbove) {
        top = aboveTop;
      } else if (fitsBelow) {
        top = belowTop;
      } else if (fitsAbove) {
        top = aboveTop;
      }
      tipRect = Rect.fromLTWH(left, top, tipW, tipH);
    }

    // Final hard separation from the spotlight (+ meal CTA for calorie).
    if (tipRect.overlaps(obstacle.inflate(2))) {
      if (hole.top - tipH - gap >= topSafe) {
        top = hole.top - tipH - gap;
      } else if (belowTop + tipH <= bottomSafe) {
        top = belowTop;
      }
    }

    final minTop = topSafe;
    final maxTop = math.max(minTop, bottomSafe - tipH);
    // Prefer staying below the card when clamp would drag the tip into it.
    var clamped = top.clamp(minTop, maxTop);
    if (isCalorie &&
        preferAbove == false &&
        Rect.fromLTWH(left, clamped, tipW, tipH).overlaps(obstacle) &&
        belowTop + tipH <= bottomSafe) {
      clamped = belowTop;
    }
    return (left: left, top: clamped);
  }

  static Rect? _morphRect(Rect? a, Rect? b, double moveT, double sizeT) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    final center = Offset.lerp(a.center, b.center, moveT)!;
    final w = _lerp(a.width, b.width, sizeT);
    final h = _lerp(a.height, b.height, sizeT);
    return Rect.fromCenter(center: center, width: w, height: h);
  }

  void _syncTargets({required bool animate}) {
    if (!mounted) return;
    final media = MediaQuery.of(context);
    final size = media.size;
    final target = _targetRect();
    if (target == null) return;
    final hole = widget.step.inflateHole(target);

    final tipW = _tipMaxWidth(size);
    final tipH = _tipHeight(media);
    final placed = _placeTip(
      size: size,
      media: media,
      hole: hole,
      tipW: tipW,
      tipH: tipH,
    );

    final holeT = _holeMove.value;
    final tipT = _tipMove.value;
    final sizeT = _sizeMove.value;
    final currentHole =
        _morphRect(_holeFrom, _holeTo, holeT, sizeT) ?? _holeTo;
    final currentLeft = _lerp(_tipLeftFrom, _tipLeftTo, tipT);
    final currentTop = _lerp(_tipTopFrom, _tipTopTo, tipT);
    final currentRadius = _lerp(_radiusFrom, _radiusTo, sizeT);

    final shouldAnimate = animate &&
        currentHole != null &&
        _boundStep >= 0 &&
        _boundStep != widget.stepIndex;

    if (!shouldAnimate) {
      _holeFrom = hole;
      _holeTo = hole;
      _tipLeftFrom = placed.left;
      _tipTopFrom = placed.top;
      _tipLeftTo = placed.left;
      _tipTopTo = placed.top;
      _tipW = tipW;
      _radiusFrom = widget.step.holeRadius;
      _radiusTo = widget.step.holeRadius;
      _boundStep = widget.stepIndex;
      _motion.value = 1;
      setState(() {});
      return;
    }

    _holeFrom = currentHole;
    _holeTo = hole;
    _tipLeftFrom = currentLeft;
    _tipTopFrom = currentTop;
    _tipLeftTo = placed.left;
    _tipTopTo = placed.top;
    _tipW = tipW;
    _radiusFrom = currentRadius;
    _radiusTo = widget.step.holeRadius;
    _boundStep = widget.stepIndex;

    final travelPx = (currentHole.center - hole.center).distance;
    final ms = (560 + travelPx * 0.28).clamp(560, 780).round();
    _motion
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
    _trackDestinationWhileMoving();
  }

  void _trackDestinationWhileMoving() {
    if (_tracking) return;
    _tracking = true;
    void tick(_) {
      if (!mounted || !_motion.isAnimating) {
        _tracking = false;
        if (mounted) _syncTargets(animate: false);
        return;
      }
      _refineDestinationOnly();
      WidgetsBinding.instance.addPostFrameCallback(tick);
    }

    WidgetsBinding.instance.addPostFrameCallback(tick);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1).clamp(0.85, 1.2);
    final holeT = _holeMove.value;
    final tipT = _tipMove.value;
    final sizeT = _sizeMove.value;

    final liveTarget = !_motion.isAnimating ? _targetRect() : null;
    final animatedHole =
        _morphRect(_holeFrom, _holeTo, holeT, sizeT) ?? _holeTo;
    final hole = liveTarget != null
        ? widget.step.inflateHole(liveTarget)
        : animatedHole;

    var tipLeft = _lerp(_tipLeftFrom, _tipLeftTo, tipT);
    var tipTop = _lerp(_tipTopFrom, _tipTopTo, tipT);
    final radius = liveTarget != null
        ? widget.step.holeRadius.toDouble()
        : _lerp(_radiusFrom, _radiusTo, sizeT);

    if (liveTarget != null && hole != null) {
      final placed = _placeTip(
        size: media.size,
        media: media,
        hole: hole,
        tipW: _tipW,
        tipH: _tipHeight(media),
      );
      tipLeft = placed.left;
      tipTop = placed.top;
    }

    final appear = _appearCurve.value;
    final tipScale = _motion.isAnimating ? _tipLift.value : 1.0;
    final tipOpacity = _motion.isAnimating ? _tipFade.value : 1.0;
    final arriveBoost = math.sin(_arrive.value * math.pi) * 0.7;
    final drawnBorder =
        (_motion.isAnimating ? _borderPulse.value : 2.5) + arriveBoost;

    final tipBelowHole =
        tipTop >= ((hole?.center.dy) ?? tipTop);
    // Scale from center so tip never expands into the spotlight.
    const tipScaleAlign = Alignment.center;
    final canAdvance =
        widget.canAdvance && appear >= 0.95;

    // Slide in from the tip's free side (never toward the hole).
    final tipSlide =
        (tipBelowHole ? 1.0 : -1.0) * (1 - appear) * 14.0;

    return Material(
      type: MaterialType.transparency,
      child: ExcludeSemantics(
        child: MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: Opacity(
            opacity: appear,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: !canAdvance
                        ? null
                        : widget.step.key == AppCoachMarks.addFoodSearchKey
                            ? widget.onSkip
                            : () {},
                    child: CustomPaint(
                      painter: _HoleDimPainter(
                        hole: hole,
                        radius: radius,
                        color: const Color(0xFF000000).withValues(alpha: 0.48),
                        cutInset: 0.5,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                if (hole != null)
                  Positioned(
                    left: hole.left,
                    top: hole.top,
                    width: hole.width,
                    height: hole.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canAdvance ? widget.onNext : null,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(
                            color: AppColors.primary,
                            width: drawnBorder.clamp(2.2, 3.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (hole != null)
                  _buildTip(
                    tipLeft: tipLeft,
                    tipTop: tipTop + tipSlide,
                    tipScale: tipScale,
                    tipScaleAlignment: tipScaleAlign,
                    tipOpacity: tipOpacity.clamp(0.0, 1.0),
                    appear: appear,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip({
    required double tipLeft,
    required double tipTop,
    required double tipScale,
    required Alignment tipScaleAlignment,
    required double tipOpacity,
    required double appear,
  }) {
    final bubble = Opacity(
      opacity: tipOpacity,
      child: Transform.scale(
        scale: tipScale,
        alignment: tipScaleAlignment,
        child: KeyedSubtree(
          key: _tipKey,
          child: CoachMarkBubble(
            title: widget.step.title,
            description: widget.step.description,
            stepIndex: widget.stepIndex,
            stepCount: widget.stepCount,
            isLast: widget.stepIndex >= widget.stepCount - 1,
            onSkip: widget.onSkip,
            onNext: widget.onNext,
            enabled: widget.canAdvance && appear >= 0.95,
          ),
        ),
      ),
    );

    final ignoring = !widget.canAdvance || appear < 0.95;
    final target = _targetRect();
    final settled = !_motion.isAnimating && target != null;

    if (settled) {
      return CompositedTransformFollower(
        link: widget.step.link,
        showWhenUnlinked: false,
        offset: Offset(tipLeft - target.left, tipTop - target.top),
        child: SizedBox(
          width: _tipW,
          child: IgnorePointer(ignoring: ignoring, child: bubble),
        ),
      );
    }

    return Positioned(
      left: tipLeft,
      top: tipTop,
      width: _tipW,
      child: IgnorePointer(ignoring: ignoring, child: bubble),
    );
  }
}

class _HoleDimPainter extends CustomPainter {
  _HoleDimPainter({
    required this.hole,
    required this.radius,
    required this.color,
    this.cutInset = 0.5,
  });

  final Rect? hole;
  final double radius;
  final Color color;
  final double cutInset;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    if (hole == null) {
      canvas.drawRect(bounds, Paint()..color = color);
      return;
    }

    final inset = cutInset.clamp(0.0, 2.0);
    final cutRect = hole!.deflate(inset);
    final cutRadius = math.max(0.0, radius - inset);
    final cutRRect =
        RRect.fromRectAndRadius(cutRect, Radius.circular(cutRadius));

    // Hard punch — avoids soft AA white fringe.
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = color);
    canvas.drawRRect(cutRRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HoleDimPainter oldDelegate) {
    return oldDelegate.hole != hole ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.cutInset != cutInset;
  }
}
