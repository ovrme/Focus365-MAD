import 'package:flutter/foundation.dart';

/// Cross-screen filter intent — lets the drawer (or any other surface)
/// push a filter change to [HomeScreen] without coupling the two.
///
/// Filter values:
///   - `'all'`              — every task
///   - `'active'`           — incomplete tasks
///   - `'completed'`        — completed tasks
///   - `'assignedToMe'`     — tasks where assigneeId == current user
///   - `'today'`            — tasks due today
///   - `'important'`        — priority == 3 (high)
///   - `'thisWeek'`         — tasks due in the next 7 days
///   - `'category:<name>'`  — tasks in a category by name
///   - `'project:<id>'`     — tasks in a project by id
///
/// HomeScreen owns its local `_filter` for chip toggles; this intent only
/// pushes external requests in. HomeScreen syncs from this notifier and
/// also calls [consume] so the same intent doesn't replay on rebuild.
class HomeFilterIntent extends ChangeNotifier {
  String? _pending;

  /// Returns and clears the latest filter set externally.
  String? consume() {
    final v = _pending;
    _pending = null;
    return v;
  }

  void setFilter(String filter) {
    _pending = filter;
    notifyListeners();
  }
}
