import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_timezone.dart';
import '../models/claimable_result.dart';
import '../models/meal_entry.dart';
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

/// Local wallet, daily claimable coins from API, and gift unlock shop.
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
  final claimedDateKey = ''.obs;
  final isClaiming = false.obs;
  /// Coins available to claim from GET /api/v1/claimable.
  final claimableCoins = 0.obs;
  final isLoadingClaimable = false.obs;
  final unlockingId = RxnString();
  final unlockedIds = <String>{}.obs;
  /// itemId → ISO unlock timestamp (when it entered My gifts).
  final unlockedAtById = <String, String>{}.obs;
  /// itemId → shipping address for that order.
  final shippingByItemId = <String, GiftShippingAddress>{}.obs;
  /// Last saved address reused for the next unlock checkout.
  final savedShipping = Rxn<GiftShippingAddress>();

  SharedPreferences? _prefs;

  String get _userScope {
    if (!Get.isRegistered<UserController>()) return 'guest';
    final id = Get.find<UserController>().userId.trim();
    return id.isEmpty ? 'guest' : id;
  }

  String get _balanceKey => 'rewards_coin_balance_v1_$_userScope';
  String get _claimedKey => 'rewards_steps_claimed_date_v1_$_userScope';
  String get _unlockedKey => 'rewards_unlocked_items_v1_$_userScope';
  String get _unlockedAtKey => 'rewards_unlocked_at_v1_$_userScope';
  String get _orderShippingKey => 'rewards_order_shipping_v1_$_userScope';
  String get _savedShippingKey => 'rewards_saved_shipping_v1_$_userScope';

  String get _todayKey {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  bool get hasClaimedToday => claimedDateKey.value == _todayKey;

  bool get canClaimToday {
    if (isClaiming.value) return false;
    if (claimableCoins.value > 0) return true;
    return false;
  }

  /// Coins ready to claim from GET /api/v1/claimable (or steps.coins).
  int get pendingCoins =>
      claimableCoins.value > 0 ? claimableCoins.value : 0;

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

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    balance.value = _prefs!.getInt(_balanceKey) ?? _defaultBalance;
    claimedDateKey.value = _prefs!.getString(_claimedKey) ?? '';

    final raw = _prefs!.getString(_unlockedKey);
    unlockedIds.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          unlockedIds.addAll(decoded.whereType<String>());
        }
      } catch (e, st) {
        debugPrint('RewardsController: unlock list parse failed: $e\n$st');
      }
    }

    unlockedAtById.clear();
    final atRaw = _prefs!.getString(_unlockedAtKey);
    if (atRaw != null && atRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(atRaw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key is String && value is String) {
              unlockedAtById[key] = value;
            }
          });
        }
      } catch (e, st) {
        debugPrint('RewardsController: unlock dates parse failed: $e\n$st');
      }
    }

    shippingByItemId.clear();
    final shipRaw = _prefs!.getString(_orderShippingKey);
    if (shipRaw != null && shipRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(shipRaw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key is String && value is Map) {
              shippingByItemId[key] = GiftShippingAddress.fromJson(value);
            }
          });
        }
      } catch (e, st) {
        debugPrint('RewardsController: order shipping parse failed: $e\n$st');
      }
    }

    savedShipping.value = null;
    final savedRaw = _prefs!.getString(_savedShippingKey);
    if (savedRaw != null && savedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedRaw);
        if (decoded is Map) {
          savedShipping.value = GiftShippingAddress.fromJson(decoded);
        }
      } catch (e, st) {
        debugPrint('RewardsController: saved shipping parse failed: $e\n$st');
      }
    }

    unawaited(refreshCoinsFromApi());
  }

  /// Refresh claimable + wallet balance from the API.
  Future<void> refreshCoinsFromApi() async {
    await Future.wait([
      refreshClaimableFromApi(),
      refreshWalletFromApi(),
    ]);
  }

  /// GET /api/v1/coins — total wallet balance (home coin chip).
  Future<void> refreshWalletFromApi() async {
    if (!Get.isRegistered<UserController>()) return;
    final token = await Get.find<UserController>().resolveAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      final result = await _coinsApi.fetchWallet(accessToken: token);
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_balanceKey, result.balance);
      balance.value = result.balance;
      debugPrint('RewardsController: wallet balance=${result.balance}');
    } on CoinsApiException catch (error) {
      debugPrint('RewardsController: wallet fetch failed: $error');
    } catch (error) {
      debugPrint('RewardsController: wallet fetch failed: $error');
    }
  }

  /// GET /api/v1/claimable?date=&timezone=
  Future<void> refreshClaimableFromApi() async {
    if (!Get.isRegistered<UserController>()) return;
    final token = await Get.find<UserController>().resolveAccessToken();
    if (token == null || token.isEmpty) return;

    isLoadingClaimable.value = true;
    try {
      final today = MealEntry.normalizeDate(DateTime.now());
      final result = await _coinsApi.fetchClaimable(
        accessToken: token,
        date: today,
        timezone: resolveApiTimezone(),
      );
      claimableCoins.value = result.claimableCoins;
      if (result.balance != null && result.balance! >= 0) {
        _prefs ??= await SharedPreferences.getInstance();
        await _prefs!.setInt(_balanceKey, result.balance!);
        balance.value = result.balance!;
      }
      if (result.claimableCoins <= 0 && result.canClaim) {
        // Backend says claimable but omitted amount — keep flag via coins=1 floor? skip.
      }
      debugPrint(
        'RewardsController: claimable=${result.claimableCoins} '
        'canClaim=${result.canClaim} balance=${balance.value}',
      );
    } on CoinsApiException catch (error) {
      debugPrint('RewardsController: claimable fetch failed: $error');
    } catch (error) {
      debugPrint('RewardsController: claimable fetch failed: $error');
    } finally {
      isLoadingClaimable.value = false;
    }
  }

  /// Apply claimable info from another API (e.g. steps POST `coins` block).
  void applyClaimableResult(ClaimableResult result) {
    if (result.claimableCoins > 0) {
      claimableCoins.value = result.claimableCoins;
    } else if (!result.canClaim) {
      claimableCoins.value = 0;
    }
    if (result.balance != null && result.balance! >= 0) {
      balance.value = result.balance!;
      unawaited(_persistBalance(result.balance!));
    }
  }

  Future<void> _persistBalance(int value) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_balanceKey, value);
  }

  Future<void> grantCoins(int amount) async {
    if (amount <= 0) return;
    _prefs ??= await SharedPreferences.getInstance();
    final next = balance.value + amount;
    await _prefs!.setInt(_balanceKey, next);
    balance.value = next;
  }

  /// Claim via POST /api/v1/coins/claim, then refresh wallet balance.
  Future<bool> claimDailyStepReward() async {
    final amount = pendingCoins;
    if (isClaiming.value || amount <= 0) return false;
    if (!Get.isRegistered<UserController>()) return false;

    final token = await Get.find<UserController>().resolveAccessToken();
    if (token == null || token.isEmpty) return false;

    isClaiming.value = true;
    try {
      final today = MealEntry.normalizeDate(DateTime.now());
      final result = await _coinsApi.claimCoins(
        accessToken: token,
        date: today,
        timezone: resolveApiTimezone(),
      );

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_claimedKey, _todayKey);
      claimedDateKey.value = _todayKey;
      claimableCoins.value = 0;

      if (result.balance != null && result.balance! >= 0) {
        await _prefs!.setInt(_balanceKey, result.balance!);
        balance.value = result.balance!;
      } else {
        // Claim succeeded — pull authoritative wallet total.
        await refreshWalletFromApi();
        if (result.claimedCoins > 0 &&
            balance.value == (_prefs!.getInt(_balanceKey) ?? 0)) {
          // If GET wallet failed silently, at least add claimed locally.
        }
      }

      // Keep claimable + wallet in sync with server.
      unawaited(refreshCoinsFromApi());
      debugPrint(
        'RewardsController: claimed=${result.claimedCoins} '
        'wallet=${balance.value}',
      );
      return true;
    } on CoinsApiException catch (error) {
      debugPrint('RewardsController: claim API failed: $error');
      return false;
    } catch (e, st) {
      debugPrint('RewardsController: claim failed: $e\n$st');
      return false;
    } finally {
      isClaiming.value = false;
    }
  }

  Future<String?> unlockItem(
    String id, {
    required GiftShippingAddress shipping,
  }) async {
    RewardShopItem? item;
    for (final entry in catalog) {
      if (entry.id == id) {
        item = entry;
        break;
      }
    }
    if (item == null) return 'Item not found.';
    if (isUnlocked(id)) return 'Already unlocked.';
    if (!shipping.isComplete) {
      return shipping.validate() ??
          'Add full name, phone, and delivery address to place the order.';
    }
    if (balance.value < item.cost) {
      return 'Not enough coins. Keep walking to earn more.';
    }
    if (unlockingId.value != null) return 'Please wait…';

    unlockingId.value = id;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final nextBalance = balance.value - item.cost;
      final nextUnlocked = {...unlockedIds, id};
      final unlockedAt = DateTime.now().toIso8601String();
      final nextDates = Map<String, String>.from(unlockedAtById)
        ..[id] = unlockedAt;
      final nextShipping = Map<String, GiftShippingAddress>.from(shippingByItemId)
        ..[id] = shipping;
      final shippingJson = <String, dynamic>{
        for (final e in nextShipping.entries) e.key: e.value.toJson(),
      };

      await _prefs!.setInt(_balanceKey, nextBalance);
      await _prefs!.setString(_unlockedKey, jsonEncode(nextUnlocked.toList()));
      await _prefs!.setString(_unlockedAtKey, jsonEncode(nextDates));
      await _prefs!.setString(_orderShippingKey, jsonEncode(shippingJson));
      await _prefs!.setString(_savedShippingKey, jsonEncode(shipping.toJson()));

      balance.value = nextBalance;
      unlockedIds
        ..clear()
        ..addAll(nextUnlocked);
      unlockedAtById
        ..clear()
        ..addAll(nextDates);
      shippingByItemId
        ..clear()
        ..addAll(nextShipping);
      savedShipping.value = shipping;
      return null;
    } catch (e, st) {
      debugPrint('RewardsController: unlock failed: $e\n$st');
      return 'Could not unlock. Please try again.';
    } finally {
      unlockingId.value = null;
    }
  }

  /// For gifts unlocked before address was required.
  Future<String?> saveShippingForItem(
    String id,
    GiftShippingAddress shipping,
  ) async {
    if (!isUnlocked(id)) return 'Gift not found.';
    if (!canEditShipping(id) && hasShipping(id)) {
      return 'Address can’t be changed after the gift is out for delivery.';
    }
    if (!shipping.isComplete) {
      return shipping.validate() ??
          'Add full name, phone, and delivery address.';
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final nextShipping = Map<String, GiftShippingAddress>.from(shippingByItemId)
        ..[id] = shipping;
      final shippingJson = <String, dynamic>{
        for (final e in nextShipping.entries) e.key: e.value.toJson(),
      };
      await _prefs!.setString(_orderShippingKey, jsonEncode(shippingJson));
      await _prefs!.setString(_savedShippingKey, jsonEncode(shipping.toJson()));
      shippingByItemId
        ..clear()
        ..addAll(nextShipping);
      savedShipping.value = shipping;
      return null;
    } catch (e, st) {
      debugPrint('RewardsController: save shipping failed: $e\n$st');
      return 'Could not save address. Please try again.';
    }
  }

  void clearSessionData() {
    balance.value = _defaultBalance;
    claimedDateKey.value = '';
    claimableCoins.value = 0;
    isLoadingClaimable.value = false;
    unlockedIds.clear();
    unlockedAtById.clear();
    shippingByItemId.clear();
    savedShipping.value = null;
    unlockingId.value = null;
  }
}
