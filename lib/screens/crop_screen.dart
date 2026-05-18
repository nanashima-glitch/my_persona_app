import 'dart:io';
import 'package:flutter/material.dart';

class CropScreen extends StatefulWidget {
  final File image;
  const CropScreen({super.key, required this.image});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  List<Offset> points = []; 
  List<Offset> normalizedPoints = [];
  final GlobalKey _imageKey = GlobalKey(); // 画像の位置を特定するためのキー

  void _updatePoints(Offset localPosition) {
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // 画像の表示サイズと位置を取得
    final size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    // 画面全体のタッチ位置から、画像内での相対位置(0.0 ~ 1.0)を割り出す
    double dx = localPosition.dx / size.width;
    double dy = localPosition.dy / size.height;

    // 画像の範囲内だけを記録
    if (dx >= 0 && dx <= 1 && dy >= 0 && dy <= 1) {
      setState(() {
        points.add(localPosition);
        normalizedPoints.add(Offset(dx, dy));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('正確になぞる'), backgroundColor: Colors.red,
        actions: [IconButton(icon: const Icon(Icons.check), 
        onPressed: () => Navigator.pop(context, normalizedPoints))]),
      body: Center(
        child: GestureDetector(
          onPanUpdate: (details) => _updatePoints(details.localPosition),
          child: Stack(
            children: [
              Image.file(widget.image, key: _imageKey, fit: BoxFit.contain),
              CustomPaint(painter: MyClipperPainter(points), size: Size.infinite),
            ],
          ),
        ),
      ),
    );
  }
}

class MyClipperPainter extends CustomPainter {
  final List<Offset> points;
  MyClipperPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()..color = Colors.white..strokeWidth = 3.0..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var p in points) path.lineTo(p.dx, p.dy);
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}