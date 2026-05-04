import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'recurrence.dart';
import 'reminder.dart';

class Task {
  final String id;
  String title;
  String description;
  DateTime? dueDate;
  String category;
  int priority; // 1 = Low, 2 = Medium, 3 = High
  bool isCompleted;
  List<SubTask> subTasks;
  bool isRecurring;
  DateTime createdAt;
  DateTime? completedAt;
  String? userId;
  int? colorValue;

  // Production fields
  String? projectId;
  List<String> labelIds;
  RecurrenceRule? recurrenceRule;
  List<String> attachments;
  String? sharedListId;
  String? assigneeId;

  // Reference-app parity fields. All optional; absent on legacy docs.
  List<TaskReminder> reminders;
  String? emoji;
  int? estimatedMinutes;
  String? completionNote;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.category = 'General',
    this.priority = 2,
    this.isCompleted = false,
    this.subTasks = const [],
    this.isRecurring = false,
    this.userId,
    this.colorValue,
    this.projectId,
    this.labelIds = const [],
    this.recurrenceRule,
    this.attachments = const [],
    this.sharedListId,
    this.assigneeId,
    this.completedAt,
    this.reminders = const [],
    this.emoji,
    this.estimatedMinutes,
    this.completionNote,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color? get taskColor => colorValue != null ? Color(colorValue!) : null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'category': category,
      'priority': priority,
      'isCompleted': isCompleted,
      'subTasks': subTasks.map((s) => s.toJson()).toList(),
      'isRecurring': isRecurring,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'userId': userId,
      'colorValue': colorValue,
      'projectId': projectId,
      'labelIds': labelIds,
      'recurrenceRule': recurrenceRule?.toJson(),
      'attachments': attachments,
      'sharedListId': sharedListId,
      'assigneeId': assigneeId,
      // Optional fields: only emit when set so legacy docs round-trip
      // unchanged and Firestore documents stay tidy.
      if (reminders.isNotEmpty)
        'reminders': reminders.map((r) => r.toJson()).toList(),
      if (emoji != null) 'emoji': emoji,
      if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
      if (completionNote != null) 'completionNote': completionNote,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      category: json['category'] as String? ?? 'General',
      priority: json['priority'] as int? ?? 2,
      isCompleted: json['isCompleted'] as bool? ?? false,
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map((s) => SubTask.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      isRecurring: json['isRecurring'] as bool? ?? false,
      userId: json['userId'] as String?,
      colorValue: json['colorValue'] as int?,
      projectId: json['projectId'] as String?,
      labelIds: (json['labelIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      recurrenceRule: json['recurrenceRule'] != null
          ? RecurrenceRule.fromJson(
              json['recurrenceRule'] as Map<String, dynamic>)
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      sharedListId: json['sharedListId'] as String?,
      assigneeId: json['assigneeId'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((r) => TaskReminder.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      emoji: json['emoji'] as String?,
      estimatedMinutes: json['estimatedMinutes'] as int?,
      completionNote: json['completionNote'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Task.fromJson(data);
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? category,
    int? priority,
    bool? isCompleted,
    List<SubTask>? subTasks,
    bool? isRecurring,
    String? userId,
    int? colorValue,
    bool clearColor = false,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? projectId,
    bool clearProject = false,
    List<String>? labelIds,
    RecurrenceRule? recurrenceRule,
    bool clearRecurrence = false,
    List<String>? attachments,
    String? sharedListId,
    bool clearSharedList = false,
    String? assigneeId,
    bool clearAssignee = false,
    List<TaskReminder>? reminders,
    String? emoji,
    bool clearEmoji = false,
    int? estimatedMinutes,
    bool clearEstimatedMinutes = false,
    String? completionNote,
    bool clearCompletionNote = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      subTasks: subTasks ?? this.subTasks,
      isRecurring: isRecurring ?? this.isRecurring,
      userId: userId ?? this.userId,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      createdAt: createdAt ?? this.createdAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      projectId: clearProject ? null : (projectId ?? this.projectId),
      labelIds: labelIds ?? this.labelIds,
      recurrenceRule:
          clearRecurrence ? null : (recurrenceRule ?? this.recurrenceRule),
      attachments: attachments ?? this.attachments,
      sharedListId:
          clearSharedList ? null : (sharedListId ?? this.sharedListId),
      assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
      reminders: reminders ?? this.reminders,
      emoji: clearEmoji ? null : (emoji ?? this.emoji),
      estimatedMinutes: clearEstimatedMinutes
          ? null
          : (estimatedMinutes ?? this.estimatedMinutes),
      completionNote: clearCompletionNote
          ? null
          : (completionNote ?? this.completionNote),
    );
  }
}

class SubTask {
  final String id;
  String title;
  bool isCompleted;

  SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}
