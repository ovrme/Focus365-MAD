/// A single scheduled reminder for a task.
///
/// A task may have many reminders (e.g. 1 day before, 1 hour before, at due
/// time). [fireAt] is the resolved absolute time the notification should ring;
/// [offsetMinutesBeforeDue] records the original relative intent so the
/// reminder can be re-resolved if the task's due date moves.
class TaskReminder {
  final String id;
  final DateTime fireAt;
  final int? offsetMinutesBeforeDue;
  final DateTime? snoozedUntil;

  const TaskReminder({
    required this.id,
    required this.fireAt,
    this.offsetMinutesBeforeDue,
    this.snoozedUntil,
  });

  /// The effective time the notification should fire — snooze takes
  /// precedence over the original [fireAt].
  DateTime get effectiveFireAt => snoozedUntil ?? fireAt;

  TaskReminder copyWith({
    String? id,
    DateTime? fireAt,
    int? offsetMinutesBeforeDue,
    bool clearOffset = false,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
  }) {
    return TaskReminder(
      id: id ?? this.id,
      fireAt: fireAt ?? this.fireAt,
      offsetMinutesBeforeDue: clearOffset
          ? null
          : (offsetMinutesBeforeDue ?? this.offsetMinutesBeforeDue),
      snoozedUntil:
          clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fireAt': fireAt.toIso8601String(),
        if (offsetMinutesBeforeDue != null)
          'offsetMinutesBeforeDue': offsetMinutesBeforeDue,
        if (snoozedUntil != null)
          'snoozedUntil': snoozedUntil!.toIso8601String(),
      };

  factory TaskReminder.fromJson(Map<String, dynamic> json) {
    return TaskReminder(
      id: json['id'] as String,
      fireAt: DateTime.parse(json['fireAt'] as String),
      offsetMinutesBeforeDue: json['offsetMinutesBeforeDue'] as int?,
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'] as String)
          : null,
    );
  }
}
