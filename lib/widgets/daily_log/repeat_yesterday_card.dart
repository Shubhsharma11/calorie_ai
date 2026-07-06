import 'package:flutter/material.dart';

class RepeatYesterdayCard extends StatelessWidget {
  const RepeatYesterdayCard({
    super.key,
    required this.mealCount,
    required this.calories,
    required this.onRepeat,
    required this.onDismiss,
  });

  final int mealCount;
  final int calories;
  final VoidCallback onRepeat;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
 return Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.grey.shade300),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.replay_rounded,
              color: Colors.green,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              "Repeat Yesterday's Meals",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),

      const SizedBox(height: 12),

      const Text(
        "Save time by copying yesterday's meals.",
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),

      const SizedBox(height: 18),

Row(
  children: [
    Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant, size: 18),
          const SizedBox(width: 6),
          Text(
            "$mealCount meals",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),

    const SizedBox(width: 12),

    Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            "$calories kcal",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  ],
),

const SizedBox(height: 20),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: onRepeat,
    icon: const Icon(Icons.replay_rounded),
    label: const Text(
      "Repeat Meals",
      style: TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF22C55E),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  ),
),
    ],
  ),
);
  }
}