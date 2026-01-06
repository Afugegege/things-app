import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter/cupertino.dart';

class BucketListScreen extends StatelessWidget {
  const BucketListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy Bucket Data
    final List<Map<String, dynamic>> goals = [
      {'title': 'Visit Japan', 'done': false, 'color': 0xFFF8BBD0},
      {'title': 'Skydiving', 'done': true, 'color': 0xFFB39DDB},
      {'title': 'Learn Guitar', 'done': false, 'color': 0xFFC5CAE9},
      {'title': 'Write a Book', 'done': false, 'color': 0xFFB2DFDB},
      {'title': 'Run Marathon', 'done': false, 'color': 0xFFFFCCBC},
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Bucket List", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: MasonryGridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: goals.length,
        itemBuilder: (context, index) {
          final item = goals[index];
          return Container(
            height: (index % 2 == 0) ? 200 : 150, // Varying heights
            decoration: BoxDecoration(
              color: Color(item['color']),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    item['done'] ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  item['title'],
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    decoration: item['done'] ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}