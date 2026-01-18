import 'package:flutter/material.dart';
import '../models/bucket_item_model.dart';
import 'package:uuid/uuid.dart';

class BucketListProvider extends ChangeNotifier {
  final List<BucketItem> _items = [
    BucketItem(id: '1', title: 'Visit Japan', description: 'See cherry blossoms in Tokyo', isDone: false, color: const Color(0xFFF8BBD0), createdAt: DateTime.now()),
    BucketItem(id: '2', title: 'Skydiving', isDone: true, color: const Color(0xFFB39DDB), createdAt: DateTime.now()),
    BucketItem(id: '3', title: 'Learn Guitar', description: 'Master "Wonderwall"', isDone: false, color: const Color(0xFFC5CAE9), createdAt: DateTime.now()),
    BucketItem(id: '4', title: 'Write a Book', isDone: false, color: const Color(0xFFB2DFDB), createdAt: DateTime.now()),
    BucketItem(id: '5', title: 'Run Marathon', isDone: false, color: const Color(0xFFFFCCBC), createdAt: DateTime.now()),
  ];

  List<BucketItem> get items => _items;

  void addItem(String title, String desc, Color color) {
    _items.add(BucketItem(
      id: const Uuid().v4(),
      title: title,
      description: desc,
      color: color,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void updateItem(String id, String title, String desc, Color color, bool isDone) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = BucketItem(
        id: id,
        title: title,
        description: desc,
        color: color,
        isDone: isDone,
        createdAt: _items[index].createdAt,
      );
      notifyListeners();
    }
  }

  void deleteItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void toggleDone(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = _items[index];
      _items[index] = BucketItem(
        id: item.id,
        title: item.title,
        description: item.description,
        color: item.color,
        isDone: !item.isDone,
        createdAt: item.createdAt,
      );
      notifyListeners();
    }
  }
}
