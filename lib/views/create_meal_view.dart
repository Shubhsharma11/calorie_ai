import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../data/indian_foods_data.dart';
import '../models/custom_meal_preset.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';
import '../models/saved_meal_item.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/filter_chip_pill.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/responsive_page.dart';

class CreateMealView extends StatefulWidget {
  const CreateMealView({super.key});

  @override
  State<CreateMealView> createState() => _CreateMealViewState();
}

class _CreateMealViewState extends State<CreateMealView> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  late final FoodController _food = Get.find<FoodController>();
  late String _selectedMeal;
  final List<SavedMealItem> _items = [];
  List<FoodItem> _searchResults = [];
  bool _isSaving = false;
  bool _isSearching = false;
  MealShareVisibility _visibility = MealShareVisibility.onlyMe;
  CustomMealPreset? _editingPreset;
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  bool get _isEditing => _editingPreset != null;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is CustomMealPreset) {
      _editingPreset = args;
      _nameController.text = args.name;
      _selectedMeal = MealType.all.contains(args.meal)
          ? args.meal
          : MealType.breakfast;
      _visibility = args.visibility;
      _items.addAll(args.items);
    } else {
      final initial = args is String && MealType.all.contains(args)
          ? args
          : _food.selectedMeal.value;
      _selectedMeal =
          MealType.all.contains(initial) ? initial : MealType.breakfast;
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<FoodItem> _localSearchResults(String query) {
    final lower = query.toLowerCase();
    return indianFoods
        .where((food) => food.name.toLowerCase().contains(lower))
        .take(8)
        .toList();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final requestId = ++_searchRequestId;
    final localResults = _localSearchResults(query);
    setState(() {
      _searchResults = localResults;
      _isSearching = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final apiResults = await _food.searchFoodsEphemeral(query);
        if (!mounted || requestId != _searchRequestId) return;
        if (_searchController.text.trim() != query) return;

        setState(() {
          _searchResults = apiResults.isNotEmpty
              ? apiResults.take(8).toList()
              : localResults;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() => _isSearching = false);
      }
    });
  }

  int get _totalCalories =>
      _items.fold(0, (sum, item) => sum + item.calories);

  double get _totalCarbs => _items.fold(
        0.0,
        (sum, item) =>
            sum + item.food.macroForGrams(item.food.carbs, item.grams),
      );

  double get _totalProtein => _items.fold(
        0.0,
        (sum, item) =>
            sum + item.food.macroForGrams(item.food.protein, item.grams),
      );

  double get _totalFat => _items.fold(
        0.0,
        (sum, item) => sum + item.food.macroForGrams(item.food.fat, item.grams),
      );

  double get _macroCalories =>
      _totalCarbs * 4 + _totalProtein * 4 + _totalFat * 9;

  double _macroShare(double grams, double kcalPerGram) {
    if (_macroCalories <= 0) return 0;
    return (grams * kcalPerGram) / _macroCalories;
  }

  void _addFood(FoodItem food) {
    setState(() {
      _items.add(
        SavedMealItem(food: food, grams: 100, meal: _selectedMeal),
      );
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _updateGrams(int index, int grams) {
    if (grams < 1) return;
    setState(() {
      _items[index] = _items[index].copyWith(grams: grams);
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _save({required bool logAfterSave}) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.error('Give your meal a name first.', title: 'Name required');
      return;
    }
    if (_items.isEmpty) {
      AppSnackbar.error('Add at least one food.', title: 'No foods');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final preset = CustomMealPreset(
        id: _editingPreset?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        createdAt: _editingPreset?.createdAt ?? DateTime.now(),
        meal: _selectedMeal,
        items: _items
            .map((item) => item.copyWith(meal: _selectedMeal))
            .toList(),
        visibility: _visibility,
      );

      final savedPreset = await _food.saveCustomMealPreset(preset);

      if (logAfterSave) {
        _food.logCustomMealPreset(savedPreset, meal: _selectedMeal);
      }

      if (!mounted) return;
      Get.back<void>();

      AppSnackbar.success(
        logAfterSave
            ? '$name saved and logged to $_selectedMeal.'
            : _isEditing
                ? '$name updated in My Meals.'
                : '$name saved to My Meals.',
        title: logAfterSave ? 'Saved & logged' : 'Saved',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppAppBar(title: _isEditing ? 'Edit meal' : 'Create meal'),
      body: Column(
        children: [
          Expanded(
            child: ResponsivePage(
              scrollable: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Meal details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'e.g. Office lunch bowl',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: r.scale(16),
                              vertical: r.scale(14),
                            ),
                          ),
                        ),
                        SizedBox(height: r.scale(14)),
                        Text(
                          'Default slot',
                          style: TextStyle(
                            fontSize: r.scale(12),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: r.scale(8)),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: MealType.all.map((meal) {
                              return Padding(
                                padding: EdgeInsets.only(right: r.scale(8)),
                                child: FilterChipPill(
                                  label: meal,
                                  selected: _selectedMeal == meal,
                                  onTap: () =>
                                      setState(() => _selectedMeal = meal),
                                  fontSize: r.scale(12),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (r.isCompact) ...[
                          Text(
                            'Share with',
                            style: TextStyle(
                              fontSize: r.scale(16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: r.scale(10)),
                          _ShareInlineToggle(
                            visibility: _visibility,
                            onChanged: (value) =>
                                setState(() => _visibility = value),
                          ),
                        ] else
                          Row(
                            children: [
                              Text(
                                'Share with',
                                style: TextStyle(
                                  fontSize: r.scale(16),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              _ShareInlineToggle(
                                visibility: _visibility,
                                onChanged: (value) =>
                                    setState(() => _visibility = value),
                              ),
                            ],
                          ),
                        SizedBox(height: r.scale(8)),
                        Text(
                          _visibility == MealShareVisibility.public
                              ? 'Public is saved on this device for now. Community sharing is coming soon.'
                              : 'Only you can see and use this meal template.',
                          style: TextStyle(
                            fontSize: r.scale(12),
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  _MacroRingPanel(
                    calories: _totalCalories,
                    carbsG: _totalCarbs,
                    proteinG: _totalProtein,
                    fatG: _totalFat,
                    carbsShare: _macroShare(_totalCarbs, 4),
                    proteinShare: _macroShare(_totalProtein, 4),
                    fatShare: _macroShare(_totalFat, 9),
                  ),
                  SizedBox(height: r.scale(12)),
                  _SectionCard(
                    title: 'Add foods',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search foods...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _isSearching
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        if (_searchResults.isNotEmpty) ...[
                          SizedBox(height: r.scale(10)),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: List.generate(
                                _searchResults.length,
                                (index) {
                                  final food = _searchResults[index];
                                  final isLast =
                                      index == _searchResults.length - 1;
                                  return Column(
                                    children: [
                                      ListTile(
                                        onTap: () => _addFood(food),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        leading: FoodEmojiAvatar(
                                          emoji: food.emoji,
                                          size: r.scale(42),
                                        ),
                                        title: Text(
                                          food.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${food.caloriesPer100g} kcal / 100g',
                                          style: TextStyle(
                                            fontSize: r.scale(12),
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Divider(
                                          height: 1,
                                          indent: 60,
                                          color: AppColors.border,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        if (_items.isNotEmpty) ...[
                          SizedBox(height: r.scale(16)),
                          Text(
                            'Ingredients',
                            style: TextStyle(
                              fontSize: r.scale(14),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: r.scale(8)),
                          ...List.generate(_items.length, (index) {
                            final item = _items[index];
                            final isLast = index == _items.length - 1;
                            return Column(
                              children: [
                                _IngredientRow(
                                  item: item,
                                  onGramsChanged: (grams) =>
                                      _updateGrams(index, grams),
                                  onRemove: () => _removeItem(index),
                                ),
                                if (!isLast)
                                  Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                              ],
                            );
                          }),
                        ] else if (_searchResults.isEmpty) ...[
                          SizedBox(height: r.scale(12)),
                          _EmptyIngredientsHint(r: r),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(100)),
                ],
              ),
            ),
          ),
          _BottomActionBar(
            selectedMeal: _selectedMeal,
            isSaving: _isSaving,
            isEditing: _isEditing,
            onSaveAndLog: () => _save(logAfterSave: true),
            onSaveOnly: () => _save(logAfterSave: false),
          ),
        ],
      ),
    );
  }
}

abstract final class _MealMacroColors {
  static const carbs = Color(0xFF2196F3);
  static const fat = Color(0xFF9C27B0);
  static const protein = Color(0xFF4CAF50);
}

class _MacroRingPanel extends StatelessWidget {
  const _MacroRingPanel({
    required this.calories,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.carbsShare,
    required this.proteinShare,
    required this.fatShare,
  });

  final int calories;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double carbsShare;
  final double proteinShare;
  final double fatShare;

  bool get _hasData => calories > 0;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final ringSize = r.scale(r.isCompact ? 96 : 112, tablet: 124);
    final strokeWidth = r.scale(r.isCompact ? 9 : 11);
    final stackVertically = r.isCompact || r.width < 380;

    final ring = SizedBox(
      width: ringSize,
      height: ringSize,
      child: CustomPaint(
        painter: _MacroDonutPainter(
          carbsShare: carbsShare,
          fatShare: fatShare,
          proteinShare: proteinShare,
          strokeWidth: strokeWidth,
          trackColor: AppColors.surface,
        ),
        child: Center(
          child: _hasData
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$calories',
                      style: TextStyle(
                        fontSize: r.scale(r.isCompact ? 18 : 22),
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: r.scale(13),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: r.scale(22),
                      color: AppColors.textSecondary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    SizedBox(height: r.scale(4)),
                    Text(
                      'Add foods',
                      style: TextStyle(
                        fontSize: r.scale(11),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MacroLegendRow(
          color: _MealMacroColors.carbs,
          label: 'Carbs',
          grams: carbsG,
          share: carbsShare,
        ),
        SizedBox(height: r.scale(10)),
        _MacroLegendRow(
          color: _MealMacroColors.fat,
          label: 'Fat',
          grams: fatG,
          share: fatShare,
        ),
        SizedBox(height: r.scale(10)),
        _MacroLegendRow(
          color: _MealMacroColors.protein,
          label: 'Protein',
          grams: proteinG,
          share: proteinShare,
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(r.scale(20)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: stackVertically
          ? Column(
              children: [
                ring,
                SizedBox(height: r.scale(14)),
                legend,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ring,
                SizedBox(width: r.scale(16)),
                Expanded(child: legend),
              ],
            ),
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  const _MacroDonutPainter({
    required this.carbsShare,
    required this.fatShare,
    required this.proteinShare,
    required this.strokeWidth,
    required this.trackColor,
  });

  final double carbsShare;
  final double fatShare;
  final double proteinShare;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final segments = <(double, Color)>[
      (carbsShare, _MealMacroColors.carbs),
      (fatShare, _MealMacroColors.fat),
      (proteinShare, _MealMacroColors.protein),
    ];

    var currentAngle = startAngle;
    for (final (share, color) in segments) {
      if (share <= 0) continue;
      final sweep = 2 * math.pi * share;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, currentAngle, sweep, false, paint);
      currentAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_MacroDonutPainter old) =>
      old.carbsShare != carbsShare ||
      old.fatShare != fatShare ||
      old.proteinShare != proteinShare ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor;
}

class _MacroLegendRow extends StatelessWidget {
  const _MacroLegendRow({
    required this.color,
    required this.label,
    required this.grams,
    required this.share,
  });

  final Color color;
  final String label;
  final double grams;
  final double share;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        Container(
          width: r.scale(10),
          height: r.scale(10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: r.scale(10)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          grams > 0 ? '${grams.round()}g' : '—',
          style: TextStyle(
            fontSize: r.scale(13),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.title,
  });

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(r.scale(20)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: r.scale(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.scale(12)),
          ],
          child,
        ],
      ),
    );
  }
}

class _EmptyIngredientsHint extends StatelessWidget {
  const _EmptyIngredientsHint({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: r.scale(20),
        horizontal: r.scale(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_rounded,
            size: r.scale(32),
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            'No foods added yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: r.scale(14),
            ),
          ),
          SizedBox(height: r.scale(4)),
          Text(
            'Search above and tap a food to build your meal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(12),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.item,
    required this.onGramsChanged,
    required this.onRemove,
  });

  final SavedMealItem item;
  final ValueChanged<int> onGramsChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final stackControls = r.isCompact;

    final info = Row(
      children: [
        FoodEmojiAvatar(emoji: item.food.emoji, size: r.scale(44)),
        SizedBox(width: r.scale(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.food.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: r.scale(14),
                ),
              ),
              Text(
                '${item.calories} kcal',
                style: TextStyle(
                  fontSize: r.scale(12),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (!stackControls) ...[
          _GramStepper(
            grams: item.grams,
            onChanged: onGramsChanged,
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline_rounded, size: r.scale(20)),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.scale(8)),
      child: stackControls
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                SizedBox(height: r.scale(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _GramStepper(
                      grams: item.grams,
                      onChanged: onGramsChanged,
                    ),
                    IconButton(
                      onPressed: onRemove,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: r.scale(20),
                      ),
                      color: AppColors.textSecondary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            )
          : info,
    );
  }
}

class _ShareInlineToggle extends StatelessWidget {
  const _ShareInlineToggle({
    required this.visibility,
    required this.onChanged,
  });

  final MealShareVisibility visibility;
  final ValueChanged<MealShareVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(3)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r.scale(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShareChip(
            label: 'Only me',
            selected: visibility == MealShareVisibility.onlyMe,
            onTap: () => onChanged(MealShareVisibility.onlyMe),
          ),
          _ShareChip(
            label: 'Public',
            selected: visibility == MealShareVisibility.public,
            onTap: () => onChanged(MealShareVisibility.public),
          ),
        ],
      ),
    );
  }
}

class _ShareChip extends StatelessWidget {
  const _ShareChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: selected ? AppColors.card : Colors.transparent,
      borderRadius: BorderRadius.circular(r.scale(9)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.scale(9)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(12),
            vertical: r.scale(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(12),
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GramStepper extends StatelessWidget {
  const _GramStepper({
    required this.grams,
    required this.onChanged,
  });

  final int grams;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r.scale(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onTap: grams > 25 ? () => onChanged(grams - 25) : null,
          ),
          SizedBox(
            width: r.scale(40),
            child: Text(
              '${grams}g',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: r.scale(12),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onTap: () => onChanged(grams + 25),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.scale(8)),
      child: SizedBox(
        width: r.scale(36),
        height: r.scale(36),
        child: Icon(
          icon,
          size: r.scale(16),
          color: onTap == null
              ? AppColors.textSecondary.withValues(alpha: 0.35)
              : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.selectedMeal,
    required this.isSaving,
    required this.isEditing,
    required this.onSaveAndLog,
    required this.onSaveOnly,
  });

  final String selectedMeal;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onSaveAndLog;
  final VoidCallback onSaveOnly;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.fromLTRB(
        r.pagePadding.left,
        r.scale(12),
        r.pagePadding.right,
        r.scale(12) + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: r.scale(50),
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSaving ? null : onSaveAndLog,
                  child: isSaving
                      ? SizedBox(
                          width: r.scale(22),
                          height: r.scale(22),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          isEditing
                              ? 'Update & log to $selectedMeal'
                              : 'Save & log to $selectedMeal',
                          style: TextStyle(fontSize: r.scale(14)),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
              TextButton(
                onPressed: isSaving ? null : onSaveOnly,
                child: Text(
                  isEditing
                      ? 'Update in My Meals only'
                      : 'Save to My Meals only',
                  style: TextStyle(fontSize: r.scale(13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
