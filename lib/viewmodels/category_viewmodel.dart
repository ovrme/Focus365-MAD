import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class CategoryViewModel extends ChangeNotifier {
  final CategoryService _categoryService = CategoryService();

  List<TaskCategory> _categories = TaskCategory.defaultCategories;
  bool _isLoading = false;

  List<TaskCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _categories = await _categoryService.getCategories(userId);
    } catch (e) {
      _categories = TaskCategory.defaultCategories;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(TaskCategory category) async {
    try {
      await _categoryService.addCategory(category);
      // Replace any existing entry with the same id (e.g. overriding a
      // default) so the merged list stays unique.
      _categories.removeWhere((c) => c.id == category.id);
      _categories.add(category);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateCategory(TaskCategory category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx == -1) return;
    final old = _categories[idx];
    _categories[idx] = category;
    notifyListeners();
    try {
      await _categoryService.updateCategory(category);
    } catch (_) {
      _categories[idx] = old;
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _categoryService.deleteCategory(categoryId);
      _categories.removeWhere((c) => c.id == categoryId);
      notifyListeners();
    } catch (_) {}
  }

  void reset() {
    _categories = TaskCategory.defaultCategories;
    _isLoading = false;
    notifyListeners();
  }
}
