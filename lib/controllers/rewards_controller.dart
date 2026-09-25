import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_timezone.dart';
import '../models/claimable_result.dart';
import '../models/meal_entry.dart';
import '../services/api_client.dart';
import '../services/coins_api_service.dart';
import 'tracker_controller.dart';
import 'user_controller.dart';

class RewardShopItem {
  const RewardShopItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.cost,
    required this.icon,
    required this.accent,
    this.imageAsset,
  });

  final String id;
  final String name;
  final String subtitle;
  final int cost;
  final IconData icon;
  final Color accent;
  final String? imageAsset;
}

/// Delivery address collected at unlock (required to ship physical gifts).
class GiftShippingAddress {
  const GiftShippingAddress({
    required this.fullName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.pincode,
  });

  final String fullName;
  final String phone;
  final String line1;
  final String city;
  final String pincode;

  bool get isComplete =>
      fullName.trim().length >= 2 &&
      RegExp(r'^[A-Za-z][A-Za-z .]{1,48}$').hasMatch(fullName.trim()) &&
      _normalizedPhone(phone).length == 10 &&
      line1.trim().length >= 8 &&
      city.trim().length >= 2 &&
      RegExp(r'^[A-Za-z][A-Za-z .]{1,40}$').hasMatch(city.trim()) &&
      RegExp(r'^\d{6}$').hasMatch(pincode.trim());

  String get phoneDisplay {
    final digits = _normalizedPhone(phone);
    if (digits.length != 10) return phone.trim();
    return '${digits.substring(0, 5)} ${digits.substring(5)}';
  }

  String get oneLine =>
      '${line1.trim()}, ${city.trim()} - ${pincode.trim()}'.trim();

  String? validate() {
    if (fullName.trim().length < 2) return 'Enter full name';
    if (!RegExp(r'^[A-Za-z][A-Za-z .]{1,48}$').hasMatch(fullName.trim())) {
      return 'Enter a valid name';
    }
    if (_normalizedPhone(phone).length != 10) {
      return 'Enter a 10-digit phone number';
    }
    if (line1.trim().length < 8) return 'Enter a complete address';
    if (city.trim().length < 2 ||
        !RegExp(r'^[A-Za-z][A-Za-z .]{1,40}$').hasMatch(city.trim())) {
      return 'Enter a valid city';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pincode.trim())) {
      return 'Enter a 6-digit PIN code';
    }
    return null;
  }

  Map<String, String> toJson() => {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'line1': line1.trim(),
        'city': city.trim(),
        'pincode': pincode.trim(),
      };

  factory GiftShippingAddress.fromJson(Map<dynamic, dynamic> json) {
    return GiftShippingAddress(
      fullName: (json['fullName'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      line1: (json['line1'] as String?)?.trim() ?? '',
      city: (json['city'] as String?)?.trim() ?? '',
      pincode: (json['pincode'] as String?)?.trim() ?? '',
    );
  }

  static String _normalizedPhone(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '');
}

/// Local delivery timeline for unlocked gifts (like shop order tracking).
enum GiftDeliveryStage {
  confirmed,
  processing,
  shipped,
  outForDelivery,
  delivered,
}

extension GiftDeliveryStageX on GiftDeliveryStage {
  String get shortLabel => switch (this) {
        GiftDeliveryStage.confirmed => 'Order confirmed',
        GiftDeliveryStage.processing => 'Processing',
        GiftDeliveryStage.shipped => 'Shipped',
        GiftDeliveryStage.outForDelivery => 'Out for delivery',
        GiftDeliveryStage.delivered => 'Delivered',
      };

  /// Compact label for My gifts chips (avoids truncation).
  String get chipLabel => switch (this) {
        GiftDeliveryStage.confirmed => 'Confirmed',
        GiftDeliveryStage.processing => 'Processing',
        GiftDeliveryStage.shipped => 'Shipped',
        GiftDeliveryStage.outForDelivery => 'Out today',
        GiftDeliveryStage.delivered => 'Delivered',
      };

  String get detail => switch (this) {
        GiftDeliveryStage.confirmed =>
          'Your gift is confirmed. We’re getting it ready.',
        GiftDeliveryStage.processing =>
          'We’re packing your gift at our warehouse.',
        GiftDeliveryStage.shipped =>
          'Your gift is on the way to you.',
        GiftDeliveryStage.outForDelivery =>
          'Your gift is out for delivery today.',
        GiftDeliveryStage.delivered =>
          'Your gift has been delivered. Enjoy!',
      };

  Color get color => switch (this) {
        GiftDeliveryStage.confirmed => const Color(0xFF2F80ED),
        GiftDeliveryStage.processing => const Color(0xFFFF9500),
        GiftDeliveryStage.shipped => const Color(0xFF5AC8FA),
        GiftDeliveryStage.outForDelivery => const Color(0xFFAF52DE),
        GiftDeliveryStage.delivered => const Color(0xFF1B8F3A),
      };

  IconData get icon => switch (this) {
        GiftDeliveryStage.confirmed => Icons.receipt_long_rounded,
        GiftDeliveryStage.processing => Icons.inventory_2_rounded,
        GiftDeliveryStage.shipped => Icons.local_shipping_rounded,
        GiftDeliveryStage.outForDelivery => Icons.delivery_dining_rounded,
        GiftDeliveryStage.delivered => Icons.check_circle_rounded,
      };

  int get stepIndex => index;
}

/// API-backed wallet + claimable coins. Shop catalog is local UI only —
/// purchases are not supported until a backend spend endpoint exists.
class RewardsController extends GetxController {
  RewardsController({CoinsApiService? coinsApi})
      : _coinsApi = coinsApi ?? CoinsApiService();

  static const int dailyStepRewardCoins = 50;
  static const int _defaultBalance = 0;

  final CoinsApiService _coinsApi;

  static const catalog = <RewardShopItem>[
    RewardShopItem(
      id: 'duffel_bag',
      name: 'Fitness Hoodie',
      subtitle: 'Soft fit for daily training',
      cost: 800,
      icon: Icons.checkroom_rounded,
      accent: Color(0xFF2BBBAD),
      imageAsset: 'assets/image/buddy/gift_hoodie.png',
    ),
    RewardShopItem(
      id: 'water_bottle',
      name: 'Water Bottle',
      subtitle: 'Stay hydrated on every walk',
      cost: 450,
      icon: Icons.water_drop_rounded,
      accent: Color(0xFF2F80ED),
      imageAsset: 'assets/image/buddy/gift_bottle.png',
    ),
    RewardShopItem(
      id: 'shaker',
      name: 'Protein Shaker',
      subtitle: 'Perfect for post-workout fuel',
      cost: 350,
      icon: Icons.local_cafe_rounded,
      accent: Color(0xFF34C759),
      imageAsset: 'assets/image/buddy/gift_shaker.png',
    ),
    RewardShopItem(
      id: 'resistance_bands',
      name: 'Sticker Pack',
      subtitle: 'Fun rewards for your streak',
      cost: 600,
      icon: Icons.auto_awesome_rounded,
      accent: Color(0xFFFF9500),
      imageAsset: 'assets/image/buddy/gift_stickers.png',
    ),
    RewardShopItem(
      id: 'tshirt',
      name: 'Fitness T-Shirt',
      subtitle: 'Soft fit for daily training',
      cost: 700,
      icon: Icons.checkroom_rounded,
      accent: Color(0xFF5AC8FA),
      imageAsset: 'assets/image/buddy/gift_tshirt.png',
    ),
    RewardShopItem(
      id: 'cap',
      name: 'Running Cap',
      subtitle: 'Sun-ready for long walks',
      cost: 500,
      icon: Icons.sports_baseball_rounded,
      accent: Color(0xFFFF3B30),
      imageAsset: 'assets/image/buddy/gift_cap.png',
    ),
  ];

  final balance = _defaultBalance.obs;
  /// Lifetime earned from GET /api/v1/wallet (`lifetimeEarned`), when present.
  final lifetimeEarned = 0.obs;
  final claimedDateKey = ''.obs;
  final isClaiming = false.obs;
  /// Coins available to claim from GET /api/v1/coins/claimable (today).
  final claimableCoins = 0.obs;
  /// Today's claimable chunks from the latest claimable GET.
  final RxList<ClaimableCoinItem> claimableItems = <ClaimableCoinItem>[].obs;
  /// Claimable coins keyed by `YYYY-MM-DD` (today, yesterday, custom days).
  final RxMap<String, int> claimableByDate = <String, int>{}.obs;
  /// Claimable chunks keyed by `YYYY-MM-DD`.
  final RxMap<String, List<ClaimableCoinItem>> claimableItemsByDate =
      <String, List<ClaimableCoinItem>>{}.obs;
  /// Earned / display coins keyed by `YYYY-MM-DD` (from claimable API when present).
  final RxMap<String, int> earnedCoinsByDate = <String, int>{}.obs;
  final isLoadingClaimable = false.obs;
  /// True after today's claimable GET finishes (success or error).
  final hasCompletedClaimableFetch = false.obs;
  final RxnString claimableApiErrorMessage = RxnString();
  final isLoadingWallet = false.obs;
  /// True after a wallet GET finishes (success or error).
  final hasCompletedWalletFetch = false.obs;
  final RxnString walletApiErrorMessage = RxnString();
  final Map<String, Future<void>> _claimableFetchInFlight = {};
  Future<void>? _walletFetchInFlight;
  bool _walletRetryScheduled = false;
  /// Bumped in [clearSessionData] so in-flight wallet/claimable/retry cannot
  /// update a new session.
  int _sessionGeneration = 0;
  final unlockingId = RxnString();
  /// Last claim failure message (for snackbars). Cleared on each claim attempt.
  final lastClaimError = RxnString();
  final unlockedIds = <String>{}.obs;
  /// itemId → ISO unlock timestamp (when it entered My gifts).
  final unlockedAtById = <String, String>{}.obs;
  /// itemId → shipping address for that order.
  final shippingByItemId = <String, GiftShippingAddress>{}.obs;
  /// Last saved address reused for the next unlock checkout.
  final savedShipping = Rxn<GiftShippingAddress>();

  String get _userScope {
    if (!Get.isRegistered<UserController>()) return 'guest';
    final id = Get.find<UserController>().userId.trim();
    return id.isEmpty ? 'guest' : id;
  }

  /// Legacy prefs keys (no longer a source of truth — wiped on clear/load).
  String get _legacyBalanceKey => 'rewards_coin_balance_v1_$_userScope';
  String get _legacyClaimedKey => 'rewards_steps_claimed_date_v1_$_userScope';
  String get _legacyEarnedByDateKey => 'rewards_earned_by_date_v1_$_userScope';
  String get _legacyUnlockedKey => 'rewards_unlocked_items_v1_$_userScope';
  String get _legacyUnlockedAtKey => 'rewards_unlocked_at_v1_$_userScope';
  String get _legacyOrderShippingKey => 'rewards_order_shipping_v1_$_userScope';
  String get _legacySavedShippingKey => 'rewards_saved_shipping_v1_$_userScope';

  String get _todayKey {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  bool get hasClaimedToday => claimedDateKey.value == _todayKey;

  bool get canClaimToday {
    if (isClaiming.value) return false;
    return pendingCoins > 0;
  }

  /// Coins ready to claim from GET /api/v1/coins/claimable (or steps.coins).
  int get pendingCoins => claimableForDate(DateTime.now());

  int get yesterdayPendingCoins => claimableForDate(
        MealEntry.normalizeDate(DateTime.now()).subtract(const Duration(days: 1)),
      );

  int claimableForDate(DateTime date) {
    final key = MealEntry.dateToKey(MealEntry.normalizeDate(date));
    final mapped = claimableByDate[key];
    if (mapped != null) return mapped < 0 ? 0 : mapped;
    if (key == _todayKey) {
      return claimableCoins.value > 0 ? claimableCoins.value : 0;
    }
    return 0;
  }

  /// Coins to show in burn history for a day (claimable first, else earned).
  /// Never invents a fake daily reward — claim UI uses [claimableForDate] only.
  int coinsDisplayForDate(DateTime date) {
    final day = MealEntry.normalizeDate(date);
    final key = MealEntry.dateToKey(day);
    final claimable = claimableForDate(day);
    final earned = earnedCoinsByDate[key] ?? 0;
    if (claimable > 0 && earned > 0) {
      return claimable > earned ? claimable : earned;
    }
    if (claimable > 0) return claimable;
    if (earned > 0) return earned;
    return 0;
  }

  bool hasCoinsDataForDate(DateTime date) {
    final key = MealEntry.dateToKey(MealEntry.normalizeDate(date));
    return claimableByDate.containsKey(key) || earnedCoinsByDate.containsKey(key);
  }

  /// Remember the highest known day total from API responses this session
  /// (memory only — never persisted).
  void _rememberEarnedForDate(String key, int amount) {
    if (amount <= 0) return;
    final prev = earnedCoinsByDate[key] ?? 0;
    if (amount <= prev) return;
    earnedCoinsByDate[key] = amount;
    earnedCoinsByDate.refresh();
  }

  /// True when that day still has coins waiting to be claimed.
  bool canClaimForDate(DateTime date) => claimableForDate(date) > 0;

  int get todaySteps {
    if (!Get.isRegistered<TrackerController>()) return 0;
    return Get.find<TrackerController>().todaySteps;
  }

  int get stepsGoal => TrackerController.stepsGoal;

  bool isUnlocked(String id) => unlockedIds.contains(id);

  List<RewardShopItem> get ownedItems {
    final items = catalog.where((item) => isUnlocked(item.id)).toList();
    items.sort((a, b) {
      final aAt = unlockedAt(a.id) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = unlockedAt(b.id) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return items;
  }

  DateTime? unlockedAt(String id) {
    final raw = unlockedAtById[id];
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Short order id shown in tracking (like real shops).
  String orderId(String id) {
    final at = unlockedAt(id);
    final stamp = at == null
        ? '000000'
        : '${at.month.toString().padLeft(2, '0')}'
            '${at.day.toString().padLeft(2, '0')}'
            '${at.hour.toString().padLeft(2, '0')}';
    final suffix = id.hashCode.abs().toRadixString(36).toUpperCase();
    final short = suffix.length >= 4 ? suffix.substring(0, 4) : suffix.padLeft(4, '0');
    return 'MCP$stamp$short';
  }

  GiftShippingAddress? shippingFor(String id) => shippingByItemId[id];

  bool hasShipping(String id) {
    final address = shippingByItemId[id];
    return address != null && address.isComplete;
  }

  bool canEditShipping(String id) {
    if (!isUnlocked(id)) return false;
    final stage = deliveryStage(id);
    return stage != GiftDeliveryStage.outForDelivery &&
        stage != GiftDeliveryStage.delivered;
  }

  /// Prefill checkout from saved address, else profile name.
  GiftShippingAddress checkoutPrefill() {
    final saved = savedShipping.value;
    if (saved != null && saved.isComplete) return saved;
    var name = '';
    if (Get.isRegistered<UserController>()) {
      name = Get.find<UserController>().user.name.trim();
    }
    return GiftShippingAddress(
      fullName: name,
      phone: saved?.phone ?? '',
      line1: saved?.line1 ?? '',
      city: saved?.city ?? '',
      pincode: saved?.pincode ?? '',
    );
  }

  /// No address yet → waiting for details. Otherwise advances by calendar day.
  GiftDeliveryStage deliveryStage(String id) {
    if (!hasShipping(id)) return GiftDeliveryStage.confirmed;
    final at = unlockedAt(id);
    if (at == null) return GiftDeliveryStage.confirmed;
    final day0 = DateTime(at.year, at.month, at.day);
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day)
        .difference(day0)
        .inDays;
    if (days >= 5) return GiftDeliveryStage.delivered;
    if (days >= 3) return GiftDeliveryStage.outForDelivery;
    if (days >= 2) return GiftDeliveryStage.shipped;
    if (days >= 1) return GiftDeliveryStage.processing;
    return GiftDeliveryStage.confirmed;
  }

  DateTime? estimatedDelivery(String id) {
    if (!hasShipping(id)) return null;
    final at = unlockedAt(id);
    if (at == null) return null;
    return DateTime(at.year, at.month, at.day).add(const Duration(days: 5));
  }

  /// When a timeline step was / will be reached (for tracking UI).
  DateTime? stageDate(String id, GiftDeliveryStage stage) {
    final at = unlockedAt(id);
    if (at == null) return null;
    final day0 = DateTime(at.year, at.month, at.day);
    return switch (stage) {
      GiftDeliveryStage.confirmed => day0,
      GiftDeliveryStage.processing => day0.add(const Duration(days: 1)),
      GiftDeliveryStage.shipped => day0.add(const Duration(days: 2)),
      GiftDeliveryStage.outForDelivery => day0.add(const Duration(days: 3)),
      GiftDeliveryStage.delivered => day0.add(const Duration(days: 5)),
    };
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  /// Wipes legacy reward prefs (no longer a source of truth). Network hydrate
  /// is owned by [HomeHydrate].
  Future<void> load() async {
    await _wipeLegacyRewardPrefs();
  }

  Future<void> _wipeLegacyRewardPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyBalanceKey);
      await prefs.remove(_legacyClaimedKey);
      await prefs.remove(_legacyEarnedByDateKey);
      await prefs.remove(_legacyUnlockedKey);
      await prefs.remove(_legacyUnlockedAtKey);
      await prefs.remove(_legacyOrderShippingKey);
      await prefs.remove(_legacySavedShippingKey);
    } catch (e, st) {
      debugPrint('RewardsController: legacy prefs wipe failed: $e\n$st');
    }
  }

  /// Refresh claimable + wallet balance from the API.
  ///
  /// Home path loads wallet first, then today claimable; yesterday is deferred.
  Future<void> refreshCoinsFromApi({bool includeYesterday = true}) async {
    await refreshWalletFromApi(retryOnRateLimit: true);
    if (isClosed) return;
    await refreshClaimableFromApi(includeYesterday: includeYesterday);
  }

  /// GET /api/v1/coins/claimable for an extra day (yesterday / calendar pick).
  Future<void> refreshClaimableForDate(DateTime date) async {
    await _loadClaimableFor(MealEntry.normalizeDate(date));
  }

  /// Prefetch claimable/earned coins for burn-history days (skips loaded keys).
  ///
  /// Dates are loaded **sequentially** (max 1 concurrent new GET). In-flight
  /// same-date requests are joined via [_loadClaimableFor].
  Future<void> refreshClaimableForDates(Iterable<DateTime> dates) async {
    if (!Get.isRegistered<UserController>()) return;
    final token = await Get.find<UserController>().resolveAccessToken();
    if (token == null || token.isEmpty) return;

    final unique = <DateTime>{};
    for (final raw in dates) {
      unique.add(MealEntry.normalizeDate(raw));
    }

    final pending = unique.toList()
      ..sort((a, b) => b.compareTo(a));

    if (pending.isEmpty) return;

    for (final day in pending) {
      if (ApiClient.isRateLimited) return;
      final key = MealEntry.dateToKey(day);
      // Already have a result for this session — skip.
      if (claimableByDate.containsKey(key)) continue;
      // Joins in-flight same-date Future when present.
      await _loadClaimableFor(day, accessToken: token);
    }
  }

  /// GET /api/v1/wallet — total wallet balance (home coin chip).
  ///
  /// Concurrent callers join the same in-flight Future (no duplicate GET).
  Future<void> refreshWalletFromApi({bool retryOnRateLimit = false}) {
    if (!Get.isRegistered<UserController>()) return Future.value();

    final inFlight = _walletFetchInFlight;
    if (inFlight != null) {
      debugPrint('RewardsController: wallet JOIN in-flight');
      return inFlight;
    }

    // If we are globally rate-limited, wait and retry once instead of failing.
    // Never schedule a retry for auth failures (handled below).
    if (ApiClient.isRateLimited && retryOnRateLimit) {
      _scheduleWalletRetry();
      return Future.value();
    }

    late final Future<void> started;
    started = _refreshWalletFromApi(
      retryOnRateLimit: retryOnRateLimit,
    ).whenComplete(() {
      if (identical(_walletFetchInFlight, started)) {
        _walletFetchInFlight = null;
      }
    });
    _walletFetchInFlight = started;
    return started;
  }

  Future<void> _refreshWalletFromApi({required bool retryOnRateLimit}) async {
    final sessionGen = _sessionGeneration;

    final token = await Get.find<UserController>().resolveAccessToken();
    if (token == null || token.isEmpty) return;
    if (sessionGen != _sessionGeneration) return;

    isLoadingWallet.value = true;
    walletApiErrorMessage.value = null;
    try {
      final result = await _coinsApi.fetchWallet(accessToken: token);
      if (sessionGen != _sessionGeneration) {
        debugPrint('RewardsController: wallet result discarded (session cleared)');
        return;
      }
      balance.value = result.balance;
      if (result.lifetimeEarned != null) {
        lifetimeEarned.value = result.lifetimeEarned!;
      }
      walletApiErrorMessage.value = null;
      debugPrint(
        'RewardsController: wallet balance=${result.balance} '
        'lifetimeEarned=${result.lifetimeEarned} '
        'rewardType=${result.rewardType}',
      );
    } on CoinsApiException catch (error) {
      if (sessionGen != _sessionGeneration) return;
      debugPrint('RewardsController: wallet fetch failed: $error');
      // Never retry 401/403 — clear the dead session once.
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearSessionOnAuthFailure(
          endpoint: 'GET /wallet',
          statusCode: error.statusCode,
        );
        return;
      }
      walletApiErrorMessage.value = error.message;
      if (error.statusCode == 429 || ApiClient.isRateLimited) {
        ApiClient.noteRateLimited();
        if (retryOnRateLimit) _scheduleWalletRetry();
      }
    } catch (error) {
      if (sessionGen != _sessionGeneration) return;
      debugPrint('RewardsController: wallet fetch failed: $error');
      walletApiErrorMessage.value =
          'Unable to load wallet. Please check your connection.';
      if (ApiClient.isRateLimited && retryOnRateLimit) {
        _scheduleWalletRetry();
      }
    } finally {
      if (sessionGen == _sessionGeneration) {
        isLoadingWallet.value = false;
        hasCompletedWalletFetch.value = true;
      }
    }
  }

  void _scheduleWalletRetry() {
    if (_walletRetryScheduled || isClosed) return;
    final sessionGen = _sessionGeneration;
    _walletRetryScheduled = true;
    final until = ApiClient.rateLimitedUntil ??
        DateTime.now().add(const Duration(seconds: 60));
    final wait = until.difference(DateTime.now()) + const Duration(seconds: 1);
    debugPrint(
      'RewardsController: wallet retry scheduled in '
      '${wait.inSeconds.clamp(1, 120)}s',
    );
    unawaited(() async {
      await Future<void>.delayed(
        wait.isNegative ? const Duration(seconds: 5) : wait,
      );
      // Ignore retries from a previous session after logout/login.
      if (sessionGen != _sessionGeneration) {
        debugPrint('RewardsController: wallet retry discarded (session cleared)');
        return;
      }
      _walletRetryScheduled = false;
      if (isClosed) return;
      await refreshWalletFromApi(retryOnRateLimit: false);
      if (sessionGen != _sessionGeneration || isClosed) return;
      // Claimable may have failed in the same 429 window — refresh today.
      if (claimableByDate.isEmpty ||
          !claimableByDate.containsKey(_todayKey)) {
        await refreshClaimableFromApi(includeYesterday: false);
      }
    }());
  }

  /// Home Retry for today's claimable only (never yesterday).
  Future<void> retryClaimableToday() =>
      refreshClaimableFromApi(includeYesterday: false);

  /// GET /api/v1/coins/claimable?date=&timezone= for today (and optionally yesterday).
  Future<void> refreshClaimableFromApi({bool includeYesterday = true}) async {
    if (!Get.isRegistered<UserController>()) return;
    final token = await Get.find<UserController>().resolveAccessToken();
    if (token == null || token.isEmpty) return;

    isLoadingClaimable.value = true;
    claimableApiErrorMessage.value = null;
    try {
      final today = MealEntry.normalizeDate(DateTime.now());
      await _loadClaimableFor(today, accessToken: token);
      if (!includeYesterday) return;
      final yesterday = today.subtract(const Duration(days: 1));
      await _loadClaimableFor(yesterday, accessToken: token);
    } finally {
      isLoadingClaimable.value = false;
    }
  }

  Future<void> _loadClaimableFor(
    DateTime day, {
    String? accessToken,
  }) {
    if (!Get.isRegistered<UserController>()) return Future.value();
    final key = MealEntry.dateToKey(MealEntry.normalizeDate(day));
    final existing = _claimableFetchInFlight[key];
    if (existing != null) {
      debugPrint('RewardsController: claimable[$key] JOIN in-flight');
      return existing;
    }

    late final Future<void> started;
    started = _doLoadClaimableFor(
      day,
      accessToken: accessToken,
    ).whenComplete(() {
      if (identical(_claimableFetchInFlight[key], started)) {
        _claimableFetchInFlight.remove(key);
      }
    });
    _claimableFetchInFlight[key] = started;
    return started;
  }

  Future<void> _doLoadClaimableFor(
    DateTime day, {
    String? accessToken,
  }) async {
    final sessionGen = _sessionGeneration;
    final key = MealEntry.dateToKey(MealEntry.normalizeDate(day));
    final isToday = key == _todayKey;

    final token = accessToken ??
        await Get.find<UserController>().resolveAccessToken();
    if (token == null || token.isEmpty) return;
    if (sessionGen != _sessionGeneration) return;

    try {
      final result = await _coinsApi.fetchClaimable(
        accessToken: token,
        date: day,
        timezone: resolveApiTimezone(),
      );
      if (sessionGen != _sessionGeneration) {
        debugPrint(
          'RewardsController: claimable result discarded (session cleared)',
        );
        return;
      }
      claimableByDate[key] = result.claimableCoins;
      claimableByDate.refresh();
      claimableItemsByDate[key] =
          List<ClaimableCoinItem>.unmodifiable(result.items);
      claimableItemsByDate.refresh();

      final earned = result.earnedCoins ??
          (result.claimableCoins > 0 ? result.claimableCoins : null);
      final best = [
        earned ?? 0,
        result.claimableCoins,
        earnedCoinsByDate[key] ?? 0,
      ].fold<int>(0, (a, b) => a > b ? a : b);
      _rememberEarnedForDate(key, best);

      if (isToday) {
        claimableCoins.value = result.claimableCoins;
        claimableItems.assignAll(result.items);
        claimableApiErrorMessage.value = null;
        hasCompletedClaimableFetch.value = true;
      }
      if (result.balance != null && result.balance! >= 0) {
        // Optional claimable payload balance — memory only when present.
        balance.value = result.balance!;
      }
      debugPrint(
        'RewardsController: claimable[$key]=${result.claimableCoins} '
        'items=${result.items.length} earned=${earnedCoinsByDate[key]} '
        'canClaim=${result.canClaim} balance=${balance.value}',
      );
    } on CoinsApiException catch (error) {
      if (sessionGen != _sessionGeneration) return;
      // Never retry 401/403 — clear the dead session once.
      if (error.statusCode == 401 || error.statusCode == 403) {
        debugPrint('RewardsController: claimable auth failure: $error');
        await _clearSessionOnAuthFailure(
          endpoint: 'GET /coins/claimable',
          statusCode: error.statusCode,
        );
        return;
      }
      // Don't mark the day empty on rate-limits — keep any cached earned
      // total and allow a later retry to fill claimable/earned.
      final isTransient =
          error.statusCode == 429 || ApiClient.isRateLimited;
      if (isToday) {
        claimableApiErrorMessage.value = error.message;
        hasCompletedClaimableFetch.value = true;
      } else if (!isTransient) {
        claimableByDate.putIfAbsent(key, () => 0);
        claimableByDate.refresh();
      }
      debugPrint('RewardsController: claimable fetch failed ($day): $error');
    } catch (error) {
      if (sessionGen != _sessionGeneration) return;
      if (isToday) {
        claimableApiErrorMessage.value =
            'Unable to load rewards. Please check your connection.';
        hasCompletedClaimableFetch.value = true;
      }
      debugPrint('RewardsController: claimable fetch failed ($day): $error');
    }
  }

  Future<void> _clearSessionOnAuthFailure({
    required String endpoint,
    required int? statusCode,
  }) async {
    if (!Get.isRegistered<UserController>()) return;
    final user = Get.find<UserController>();
    if (user.isLoggingOut || user.isDeletingAccount || !user.isLoggedIn) {
      return;
    }
    await user.clearInvalidSession(
      // TEMPORARY — HOME_STUCK_DEBUG
      debugController: 'RewardsController',
      debugEndpoint: endpoint,
      debugStatusCode: statusCode,
      debugRequestType: 'GET',
    );
  }

  /// Apply claimable info from another API (e.g. steps POST `coins` block).
  void applyClaimableResult(ClaimableResult result) {
    if (result.claimableCoins > 0) {
      claimableCoins.value = result.claimableCoins;
    } else if (!result.canClaim) {
      claimableCoins.value = 0;
    }
    if (result.items.isNotEmpty || !result.canClaim) {
      claimableItems.assignAll(result.items);
      claimableItemsByDate[_todayKey] =
          List<ClaimableCoinItem>.unmodifiable(result.items);
      claimableItemsByDate.refresh();
    }
    claimableByDate[_todayKey] = claimableCoins.value;
    claimableByDate.refresh();
    final earned = result.earnedCoins ?? result.displayCoins;
    _rememberEarnedForDate(_todayKey, earned);
    if (result.balance != null && result.balance! >= 0) {
      balance.value = result.balance!;
    }
  }

  /// Claim via POST /api/v1/coins/claim, then refresh wallet balance.
  Future<bool> claimDailyStepReward({DateTime? date}) async {
    lastClaimError.value = null;
    final day = MealEntry.normalizeDate(date ?? DateTime.now());
    final dateKey = MealEntry.dateToKey(day);
    final amount = claimableForDate(day);
    if (isClaiming.value || amount <= 0) {
      if (amount <= 0) {
        lastClaimError.value = 'Nothing left to claim for this day.';
      }
      return false;
    }
    if (!Get.isRegistered<UserController>()) {
      lastClaimError.value = 'Sign in to claim coins.';
      return false;
    }

    final token = await Get.find<UserController>().resolveAccessToken();
    if (token == null || token.isEmpty) {
      lastClaimError.value = 'Sign in to claim coins.';
      return false;
    }

    final ids = (claimableItemsByDate[dateKey] ?? const <ClaimableCoinItem>[])
        .where((item) => item.id.isNotEmpty && item.isClaimable)
        .map((item) => item.id)
        .toList(growable: false);

    isClaiming.value = true;
    try {
      final today = MealEntry.normalizeDate(DateTime.now());
      final result = await _coinsApi.claimCoins(
        accessToken: token,
        date: day,
        timezone: resolveApiTimezone(),
        claimableIds: ids.isEmpty ? null : ids,
      );

      final credited =
          result.claimedCoins > 0 ? result.claimedCoins : amount;

      // Clear claimable for this day; keep in-memory earned display.
      claimableByDate[dateKey] = 0;
      claimableByDate.refresh();
      claimableItemsByDate[dateKey] = const [];
      claimableItemsByDate.refresh();
      _rememberEarnedForDate(dateKey, credited);

      if (day == today) {
        claimedDateKey.value = _todayKey;
        claimableCoins.value = 0;
        claimableItems.clear();
      }

      if (result.balance != null && result.balance! >= 0) {
        balance.value = result.balance!;
      }
      if (result.lifetimeEarned != null) {
        lifetimeEarned.value = result.lifetimeEarned!;
      }

      // Always re-read wallet from API after claim (authoritative balance).
      // Also re-fetch claimable so earned/claimed chunks come from the server.
      await refreshWalletFromApi();
      await refreshClaimableForDate(day);

      debugPrint(
        'RewardsController: claimed=$credited '
        'date=$dateKey ids=${ids.length} wallet=${balance.value}',
      );
      return true;
    } on CoinsApiException catch (error) {
      lastClaimError.value = error.message;
      debugPrint('RewardsController: claim API failed: $error');
      return false;
    } catch (e, st) {
      lastClaimError.value = 'Couldn’t claim coins. Try again.';
      debugPrint('RewardsController: claim failed: $e\n$st');
      return false;
    } finally {
      isClaiming.value = false;
    }
  }

  /// Claims today then yesterday when both have pending. Returns total coins claimed.
  Future<int> claimPendingStepRewards() async {
    var total = 0;
    final today = MealEntry.normalizeDate(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    for (final day in [today, yesterday]) {
      final amount = claimableForDate(day);
      if (amount <= 0) continue;
      final ok = await claimDailyStepReward(date: day);
      if (!ok) break;
      total += amount;
    }
    return total;
  }

  /// Shop spend is not wired to a backend endpoint yet.
  Future<String?> unlockItem(
    String id, {
    required GiftShippingAddress shipping,
  }) async {
    return 'Shop purchases are not available yet.';
  }

  /// Shipping is tied to server-owned purchases — unavailable without spend API.
  Future<String?> saveShippingForItem(
    String id,
    GiftShippingAddress shipping,
  ) async {
    return 'Shop purchases are not available yet.';
  }

  void clearSessionData() {
    _sessionGeneration++;
    _walletFetchInFlight = null;
    _walletRetryScheduled = false;
    _claimableFetchInFlight.clear();
    balance.value = _defaultBalance;
    lifetimeEarned.value = 0;
    claimedDateKey.value = '';
    claimableCoins.value = 0;
    claimableItems.clear();
    claimableByDate.clear();
    claimableItemsByDate.clear();
    earnedCoinsByDate.clear();
    isLoadingClaimable.value = false;
    hasCompletedClaimableFetch.value = false;
    claimableApiErrorMessage.value = null;
    isLoadingWallet.value = false;
    hasCompletedWalletFetch.value = false;
    walletApiErrorMessage.value = null;
    unlockedIds.clear();
    unlockedAtById.clear();
    shippingByItemId.clear();
    savedShipping.value = null;
    unlockingId.value = null;
    lastClaimError.value = null;
    unawaited(_wipeLegacyRewardPrefs());
  }

  @visibleForTesting
  int get debugSessionGeneration => _sessionGeneration;

  @visibleForTesting
  bool get debugWalletRetryScheduled => _walletRetryScheduled;
}
