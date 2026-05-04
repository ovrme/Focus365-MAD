import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Label {
  final String id;
  String name;
  int colorValue;
  String? userId;

  Label({
    required this.id,
    required this.name,
    this.colorValue = 0xFF9E9E9E,
    this.userId,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'userId': userId,
      };

  factory Label.fromJson(Map<String, dynamic> json) => Label(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: json['colorValue'] as int? ?? 0xFF9E9E9E,
        userId: json['userId'] as String?,
      );

  factory Label.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Label.fromJson(data);
  }
}
