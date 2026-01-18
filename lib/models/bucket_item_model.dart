import 'package:flutter/material.dart';

class BucketItem {
  final String id;
  String title;
  String? description;
  bool isDone;
  Color color;
  DateTime createdAt;

  BucketItem({
    required this.id,
    required this.title,
    this.description,
    this.isDone = false,
    required this.color,
    required this.createdAt,
  });
}
