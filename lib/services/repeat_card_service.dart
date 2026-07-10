  import 'package:intl/intl.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  class RepeatCardService {
    static const String _key = 'repeat_card_dismissed_date';

    static String get _today =>
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    static Future<bool> shouldShowCard() async {
      final prefs = await SharedPreferences.getInstance();

      final dismissedDate = prefs.getString(_key);

      return dismissedDate != _today;
    }

    static Future<void> dismissForToday() async {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_key, _today);
    }
  }