import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/label.dart';

class LabelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('labels');

  Stream<List<Label>> streamLabels(String userId) {
    return _ref
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Label.fromFirestore(doc)).toList());
  }

  Future<List<Label>> getLabels(String userId) async {
    final snap = await _ref.where('userId', isEqualTo: userId).get();
    return snap.docs.map((doc) => Label.fromFirestore(doc)).toList();
  }

  Future<void> addLabel(Label label) async {
    await _ref.doc(label.id).set(label.toJson());
  }

  Future<void> updateLabel(Label label) async {
    await _ref.doc(label.id).update(label.toJson());
  }

  Future<void> deleteLabel(String labelId) async {
    await _ref.doc(labelId).delete();
  }
}
