import 'package:flutter/material.dart';

class TaskCategory {
  final String id;
  String name;
  IconData icon;
  Color color;
  String? userId;

  TaskCategory({
    required this.id,
    required this.name,
    this.icon = Icons.label,
    this.color = Colors.blue,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.toARGB32(),
      'userId': userId,
    };
  }

  factory TaskCategory.fromJson(Map<String, dynamic> json) {
    return TaskCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: IconData(json['iconCodePoint'] as int? ?? Icons.label.codePoint,
          fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] as int? ?? Colors.blue.toARGB32()),
      userId: json['userId'] as String?,
    );
  }

  static List<TaskCategory> defaultCategories = [
    TaskCategory(id: 'general', name: 'General', icon: Icons.label, color: Colors.blue),
    TaskCategory(id: 'work', name: 'Work', icon: Icons.work, color: Colors.orange),
    TaskCategory(id: 'personal', name: 'Personal', icon: Icons.person, color: Colors.green),
    TaskCategory(id: 'shopping', name: 'Shopping', icon: Icons.shopping_cart, color: Colors.purple),
    TaskCategory(id: 'health', name: 'Health', icon: Icons.favorite, color: Colors.red),
    TaskCategory(id: 'education', name: 'Education', icon: Icons.school, color: Colors.teal),
  ];
}
