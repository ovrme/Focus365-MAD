enum RecurrenceType { daily, weekly, monthly, custom }

class RecurrenceRule {
  final RecurrenceType type;
  final int interval; // Every N days/weeks/months
  final List<int> daysOfWeek; // 1=Mon..7=Sun (for weekly)
  final DateTime? endDate;

  const RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.daysOfWeek = const [],
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'interval': interval,
        'daysOfWeek': daysOfWeek,
        'endDate': endDate?.toIso8601String(),
      };

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => RecurrenceRule(
        type: RecurrenceType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => RecurrenceType.daily,
        ),
        interval: json['interval'] as int? ?? 1,
        daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            [],
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
      );

  /// Calculate the next occurrence after [fromDate].
  DateTime? nextOccurrence(DateTime fromDate) {
    if (endDate != null && fromDate.isAfter(endDate!)) return null;

    switch (type) {
      case RecurrenceType.daily:
        return fromDate.add(Duration(days: interval));
      case RecurrenceType.weekly:
        if (daysOfWeek.isEmpty) {
          return fromDate.add(Duration(days: 7 * interval));
        }
        // Find next matching day of week
        for (int i = 1; i <= 7 * interval; i++) {
          final candidate = fromDate.add(Duration(days: i));
          if (daysOfWeek.contains(candidate.weekday)) {
            return candidate;
          }
        }
        return fromDate.add(Duration(days: 7 * interval));
      case RecurrenceType.monthly:
        return DateTime(
          fromDate.year,
          fromDate.month + interval,
          fromDate.day,
          fromDate.hour,
          fromDate.minute,
        );
      case RecurrenceType.custom:
        return fromDate.add(Duration(days: interval));
    }
  }

  String toDisplayString() {
    switch (type) {
      case RecurrenceType.daily:
        return interval == 1 ? 'Daily' : 'Every $interval days';
      case RecurrenceType.weekly:
        if (interval == 1) {
          if (daysOfWeek.isEmpty) return 'Weekly';
          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final days =
              daysOfWeek.map((d) => dayNames[d - 1]).join(', ');
          return 'Weekly ($days)';
        }
        return 'Every $interval weeks';
      case RecurrenceType.monthly:
        return interval == 1 ? 'Monthly' : 'Every $interval months';
      case RecurrenceType.custom:
        return 'Every $interval days';
    }
  }
}
