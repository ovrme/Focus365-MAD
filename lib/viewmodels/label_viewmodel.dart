import 'dart:async';
import 'package:flutter/material.dart';
import '../models/label.dart';
import '../services/label_service.dart';

class LabelViewModel extends ChangeNotifier {
  final LabelService _service = LabelService();

  List<Label> _labels = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _subscription;

  List<Label> get labels => _labels;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Label? getById(String id) {
    try {
      return _labels.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  void listenToLabels(String userId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _service.streamLabels(userId).listen(
      (labels) {
        _labels = labels;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Failed to load labels.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> loadLabels(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _labels = await _service.getLabels(userId);
    } catch (e) {
      _error = 'Failed to load labels.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addLabel(Label label) async {
    _labels.add(label);
    notifyListeners();
    try {
      await _service.addLabel(label);
    } catch (e) {
      _labels.removeWhere((l) => l.id == label.id);
      _error = 'Failed to add label.';
      notifyListeners();
    }
  }

  Future<void> updateLabel(Label label) async {
    final idx = _labels.indexWhere((l) => l.id == label.id);
    if (idx == -1) return;
    final old = _labels[idx];
    _labels[idx] = label;
    notifyListeners();
    try {
      await _service.updateLabel(label);
    } catch (e) {
      _labels[idx] = old;
      _error = 'Failed to update label.';
      notifyListeners();
    }
  }

  Future<void> deleteLabel(String labelId) async {
    final idx = _labels.indexWhere((l) => l.id == labelId);
    if (idx == -1) return;
    final removed = _labels[idx];
    _labels.removeAt(idx);
    notifyListeners();
    try {
      await _service.deleteLabel(labelId);
    } catch (e) {
      _labels.insert(idx, removed);
      _error = 'Failed to delete label.';
      notifyListeners();
    }
  }

  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _labels = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
