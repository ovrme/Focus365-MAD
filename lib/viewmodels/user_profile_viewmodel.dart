import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_profile_service.dart';

/// Caches user profiles by uid so the UI can resolve member names/avatars
/// without re-fetching each time.
class UserProfileViewModel extends ChangeNotifier {
  final UserProfileService _service = UserProfileService();

  final Map<String, AppUser> _profiles = {};
  final Set<String> _inFlight = {};

  AppUser? get(String uid) => _profiles[uid];

  String displayName(String uid, {String fallback = 'Unknown'}) {
    final p = _profiles[uid];
    if (p == null) return fallback;
    if (p.displayName.trim().isNotEmpty) return p.displayName;
    if (p.email.trim().isNotEmpty) return p.email;
    return fallback;
  }

  /// Initials for an avatar. Uses display name first, falls back to email.
  String initials(String uid) {
    final p = _profiles[uid];
    final source = (p?.displayName.trim().isNotEmpty == true)
        ? p!.displayName.trim()
        : (p?.email.trim() ?? '?');
    final parts = source.split(RegExp(r'\s+|@')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.elementAt(1).characters.first)
        .toUpperCase();
  }

  /// Fetch any uids we don't already have cached.
  Future<void> ensureLoaded(Iterable<String> uids) async {
    final missing = uids
        .where((uid) =>
            uid.isNotEmpty &&
            !_profiles.containsKey(uid) &&
            !_inFlight.contains(uid))
        .toSet()
        .toList();
    if (missing.isEmpty) return;

    _inFlight.addAll(missing);
    try {
      final profiles = await _service.getProfiles(missing);
      for (final p in profiles) {
        _profiles[p.uid] = p;
      }
    } catch (_) {
      // Silently ignore — UI will fall back to "Unknown".
    } finally {
      _inFlight.removeAll(missing);
      notifyListeners();
    }
  }

  void upsertSelf(AppUser user) {
    _profiles[user.uid] = user;
    notifyListeners();
  }

  void reset() {
    _profiles.clear();
    _inFlight.clear();
    notifyListeners();
  }
}
