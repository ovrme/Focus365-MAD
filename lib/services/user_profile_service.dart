import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('users');

  Future<AppUser?> getProfile(String uid) async {
    final doc = await _ref.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(doc.data() as Map<String, dynamic>);
  }

  /// Fetch many profiles by uid. `whereIn` is capped at 30 ids per query,
  /// so larger inputs are chunked.
  Future<List<AppUser>> getProfiles(List<String> uids) async {
    if (uids.isEmpty) return const [];

    final chunks = <List<String>>[];
    for (var i = 0; i < uids.length; i += 30) {
      chunks.add(uids.sublist(i, (i + 30).clamp(0, uids.length)));
    }

    final results = <AppUser>[];
    for (final chunk in chunks) {
      final snap =
          await _ref.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        results.add(AppUser.fromJson(doc.data() as Map<String, dynamic>));
      }
    }
    return results;
  }
}
