import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _categoriesRef => _firestore.collection('categories');

  Future<List<TaskCategory>> getCategories(String userId) async {
    final snapshot = await _categoriesRef
        .where('userId', isEqualTo: userId)
        .get();
    final custom = snapshot.docs
        .map((doc) => TaskCategory.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
    return _mergeWithDefaults(custom);
  }

  /// Merge user-defined categories with the built-in defaults so existing
  /// tasks tagged with default category names (General/Work/Personal/...)
  /// keep rendering with their icon/color even after the user adds custom
  /// ones. Custom takes precedence on id collision so a user can override
  /// a default by saving one with the same id.
  List<TaskCategory> _mergeWithDefaults(List<TaskCategory> custom) {
    final byId = <String, TaskCategory>{
      for (final d in TaskCategory.defaultCategories) d.id: d,
    };
    for (final c in custom) {
      byId[c.id] = c;
    }
    return byId.values.toList();
  }

  Future<void> addCategory(TaskCategory category) async {
    await _categoriesRef.doc(category.id).set(category.toJson());
  }

  Future<void> updateCategory(TaskCategory category) async {
    await _categoriesRef.doc(category.id).update(category.toJson());
  }

  Future<void> deleteCategory(String categoryId) async {
    await _categoriesRef.doc(categoryId).delete();
  }
}
