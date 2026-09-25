import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/planned_meal.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/weekly_meal_plan/swap_meal_sheet.dart';

class WeeklyMealMoreOptionsView extends StatefulWidget {
  const WeeklyMealMoreOptionsView({
    super.key,
    required this.current,
    required this.options,
    required this.suppressedNames,
  });

  final PlannedMeal current;
  final List<PlannedMeal> options;
  final Set<String> suppressedNames;

  @override
  State<WeeklyMealMoreOptionsView> createState() =>
      _WeeklyMealMoreOptionsViewState();
}

class _WeeklyMealMoreOptionsViewState extends State<WeeklyMealMoreOptionsView> {
  static const _filters = ['All', 'Indian', 'Light', 'High Protein', 'Quick'];

  final _search = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PlannedMeal> get _options {
    final q = _search.text.trim().toLowerCase();
    final base = widget.options.where(
      (m) =>
          m.name.toLowerCase() != widget.current.name.toLowerCase() &&
          !widget.suppressedNames.contains(m.name.toLowerCase()) &&
          (q.isEmpty ||
              m.name.toLowerCase().contains(q) ||
              m.ingredients.any((i) => i.toLowerCase().contains(q))),
    );

    return base.where((m) {
      switch (_filter) {
        case 'Indian':
          return _looksIndian(m.name);
        case 'Light':
          return m.calories <= 500;
        case 'High Protein':
          return m.proteinG >= 25;
        case 'Quick':
          return m.ingredients.length <= 3;
        default:
          return true;
      }
    }).toList();
  }

  bool _looksIndian(String name) {
    final n = name.toLowerCase();
    return n.contains('dal') ||
        n.contains('roti') ||
        n.contains('paneer') ||
        n.contains('khichdi') ||
        n.contains('rajma') ||
        n.contains('pulao') ||
        n.contains('bhurji') ||
        n.contains('sambar') ||
        n.contains('curd') ||
        n.contains('masala');
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final options = _options;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'More options'),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(16),
              r.scale(8),
              r.scale(16),
              r.scale(8),
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search meals...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: r.scale(14),
                  vertical: r.scale(12),
                ),
              ),
            ),
          ),
          SizedBox(
            height: r.scale(40),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: r.scale(16)),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => SizedBox(width: r.scale(8)),
              itemBuilder: (context, index) {
                final label = _filters[index];
                final selected = _filter == label;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = label),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: r.scale(13),
                  ),
                  backgroundColor: AppColors.card,
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          SizedBox(height: r.scale(10)),
          Expanded(
            child: options.isEmpty
                ? Center(
                    child: Text(
                      'No other meals in your plan match.',
                      style: TextStyle(
                        fontSize: r.scale(14),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      r.scale(16),
                      r.scale(4),
                      r.scale(16),
                      r.scale(24) + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: options.length,
                    separatorBuilder: (_, _) => SizedBox(height: r.scale(10)),
                    itemBuilder: (context, index) {
                      final meal = options[index];
                      return SwapOptionTile(
                        meal: meal,
                        onSwap: () => Navigator.of(context).pop(meal),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
