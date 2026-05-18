import 'package:flutter/material.dart';

class BackgroundPickerScreen extends StatelessWidget {
  const BackgroundPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 予備の背景リスト
    final List<String> backgrounds = [
      'assets/joker1.jpg',
      'assets/joker2.jpg',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('背景を選択')),
      body: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: backgrounds.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.pop(context, backgrounds[index]);
            },
            child: Image.asset(
              backgrounds[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey,
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          );
        },
      ),
    );
  }
}