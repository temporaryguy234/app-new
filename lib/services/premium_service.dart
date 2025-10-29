import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PremiumTier { free, plus, pro }

class PremiumEntitlements {
  final int swipesPerDay; // -1 = unlimited
  final int savesPerDay; // -1 = unlimited
  final int autoApplyPerWeek; // -1 = unlimited
  final int specialsPerWeek; // -1 = unlimited
  const PremiumEntitlements({
    required this.swipesPerDay,
    required this.savesPerDay,
    required this.autoApplyPerWeek,
    required this.specialsPerWeek,
  });
}

class PremiumService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  PremiumTier _parseTier(String? v, bool legacyPremium) {
    if (legacyPremium && (v == null || v.isEmpty)) return PremiumTier.plus;
    switch ((v ?? 'free').toLowerCase()) {
      case 'plus':
        return PremiumTier.plus;
      case 'pro':
        return PremiumTier.pro;
      default:
        return PremiumTier.free;
    }
  }

  PremiumEntitlements _entitlements(PremiumTier t) {
    switch (t) {
      case PremiumTier.pro:
        return const PremiumEntitlements(swipesPerDay: -1, savesPerDay: -1, autoApplyPerWeek: -1, specialsPerWeek: -1);
      case PremiumTier.plus:
        return const PremiumEntitlements(swipesPerDay: -1, savesPerDay: -1, autoApplyPerWeek: 3, specialsPerWeek: -1);
      case PremiumTier.free:
        return const PremiumEntitlements(swipesPerDay: 50, savesPerDay: 7, autoApplyPerWeek: 1, specialsPerWeek: 1);
    }
  }

  Future<(PremiumTier, PremiumEntitlements, DocumentReference<Map<String, dynamic>>?)> _state() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return (PremiumTier.free, _entitlements(PremiumTier.free), null);
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final tier = _parseTier(data['premiumTier'] as String?, data['premium'] == true);
    return (tier, _entitlements(tier), ref);
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime _weekStart(DateTime d) {
    final wd = d.weekday; // 1..7 (Mon..Sun)
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: wd - 1));
  }

  // Swipes per day
  Future<bool> canSwipe() async {
    final (tier, ent, ref) = await _state();
    if (ref == null) return true;
    if (ent.swipesPerDay < 0) return true;
    final data = (await ref.get()).data() ?? {};
    final stats = data['stats'] ?? {};
    final count = (stats['swipesToday'] ?? 0) as int;
    final ts = (stats['swipesTodayAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final todayCount = ts != null && _isSameDay(ts, now) ? count : 0;
    return todayCount < ent.swipesPerDay;
  }

  Future<void> recordSwipe() async {
    final (_, ent, ref) = await _state();
    if (ref == null) return;
    if (ent.swipesPerDay < 0) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      final now = DateTime.now();
      final ts = (stats['swipesTodayAt'] as Timestamp?)?.toDate();
      final sameDay = ts != null && _isSameDay(ts, now);
      final next = {
        ...stats,
        'swipesToday': (sameDay ? (stats['swipesToday'] ?? 0) : 0) + 1,
        'swipesTodayAt': Timestamp.fromDate(now),
      };
      tx.set(ref, {'stats': next}, SetOptions(merge: true));
    });
  }

  // Saves per day
  Future<bool> canSave() async {
    final (tier, ent, ref) = await _state();
    if (ref == null) return true;
    if (ent.savesPerDay < 0) return true;
    final data = (await ref.get()).data() ?? {};
    final stats = data['stats'] ?? {};
    final count = (stats['savesToday'] ?? 0) as int;
    final ts = (stats['savesTodayAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final todayCount = ts != null && _isSameDay(ts, now) ? count : 0;
    return todayCount < ent.savesPerDay;
  }

  Future<void> recordSave() async {
    final (_, ent, ref) = await _state();
    if (ref == null) return;
    if (ent.savesPerDay < 0) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      final now = DateTime.now();
      final ts = (stats['savesTodayAt'] as Timestamp?)?.toDate();
      final sameDay = ts != null && _isSameDay(ts, now);
      final next = {
        ...stats,
        'savesToday': (sameDay ? (stats['savesToday'] ?? 0) : 0) + 1,
        'savesTodayAt': Timestamp.fromDate(now),
      };
      tx.set(ref, {'stats': next}, SetOptions(merge: true));
    });
  }

  // Specials per week
  Future<bool> canUseSpecials() async {
    final (tier, ent, ref) = await _state();
    if (ref == null) return true;
    if (ent.specialsPerWeek < 0) return true;
    final data = (await ref.get()).data() ?? {};
    final stats = data['stats'] ?? {};
    final count = (stats['specialsWeekCount'] ?? 0) as int;
    final ts = (stats['specialsWeekAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final start = _weekStart(now);
    final valid = ts != null && _weekStart(ts) == start ? count : 0;
    return valid < ent.specialsPerWeek;
  }

  Future<void> recordSpecialsUse() async {
    final (_, ent, ref) = await _state();
    if (ref == null) return;
    if (ent.specialsPerWeek < 0) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      final now = DateTime.now();
      final start = _weekStart(now);
      final ts = (stats['specialsWeekAt'] as Timestamp?)?.toDate();
      final sameWeek = ts != null && _weekStart(ts) == start;
      final next = {
        ...stats,
        'specialsWeekCount': (sameWeek ? (stats['specialsWeekCount'] ?? 0) : 0) + 1,
        'specialsWeekAt': Timestamp.fromDate(now),
      };
      tx.set(ref, {'stats': next}, SetOptions(merge: true));
    });
  }

  // Auto-apply per week
  Future<bool> canAutoApply() async {
    final (tier, ent, ref) = await _state();
    if (ref == null) return false;
    if (ent.autoApplyPerWeek < 0) return true;
    final data = (await ref.get()).data() ?? {};
    final stats = data['stats'] ?? {};
    final count = (stats['autoApplyWeekCount'] ?? 0) as int;
    final ts = (stats['autoApplyWeekAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final start = _weekStart(now);
    final valid = ts != null && _weekStart(ts) == start ? count : 0;
    return valid < ent.autoApplyPerWeek;
  }

  Future<void> recordAutoApply() async {
    final (_, ent, ref) = await _state();
    if (ref == null) return;
    if (ent.autoApplyPerWeek < 0) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      final now = DateTime.now();
      final start = _weekStart(now);
      final ts = (stats['autoApplyWeekAt'] as Timestamp?)?.toDate();
      final sameWeek = ts != null && _weekStart(ts) == start;
      final next = {
        ...stats,
        'autoApplyWeekCount': (sameWeek ? (stats['autoApplyWeekCount'] ?? 0) : 0) + 1,
        'autoApplyWeekAt': Timestamp.fromDate(now),
      };
      tx.set(ref, {'stats': next}, SetOptions(merge: true));
    });
  }

  Future<bool> isPremium() async {
    final (tier, _, __) = await _state();
    return tier != PremiumTier.free;
  }
}


