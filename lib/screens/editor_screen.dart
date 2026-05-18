
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix_gesture_detector/matrix_gesture_detector.dart';
import 'package:gal/gal.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'crop_screen.dart';
import 'background_picker_screen.dart';

// 共通データクラス
abstract class EditableItem {
  ValueNotifier<Matrix4> notifier = ValueNotifier(Matrix4.identity());
  Color color = Colors.white;
  double width = 0.0; 
}

class CroppedPart extends EditableItem {
  final File imageFile;
  final List<Offset> points;
  CroppedPart(this.imageFile, this.points);
}

class DrawingPath extends EditableItem {
  final List<Offset> points;
  DrawingPath(this.points);
}

class EditorScreen extends StatefulWidget {
  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey _saveKey = GlobalKey(); 
  File? _customBgFile;
  String? _presetBgAsset;
  bool _isBgLocked = false;
  bool _isPencilMode = false;
  List<Offset> _currentPoints = [];
  ValueNotifier<Matrix4> _bgNotifier = ValueNotifier(Matrix4.identity());
  
  List<EditableItem> _activeItems = []; 
  List<CroppedPart> _savedParts = []; 
  EditableItem? _selectedItem;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('PERSONA EDITOR'),
        backgroundColor: Colors.red,
        actions: [
          // 1つ前の操作を取り消すボタン
          if (_activeItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: () => setState(() {
                _activeItems.removeLast();
                _selectedItem = null;
              }),
            ),
          IconButton(icon: const Icon(Icons.download), onPressed: _exportImage),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {
            _activeItems.clear();
            _selectedItem = null;
          })),
        ],
      ),
      body: Column(
        children: [
          const Spacer(flex: 1),
          // 1. 編集キャンバス
          Expanded(
            flex: 12,
            child: RepaintBoundary(
              key: _saveKey,
              child: ClipRect(
                child: Stack(
                  children: [
                    MatrixGestureDetector(
                      onMatrixUpdate: (m, tm, sm, rm) { if (!_isBgLocked) _bgNotifier.value = m; },
                      child: AnimatedBuilder(
                        animation: _bgNotifier,
                        builder: (context, child) => Transform(
                          transform: _bgNotifier.value,
                          child: _buildBackground(),
                        ),
                      ),
                    ),
                    for (var item in _activeItems)
                      MatrixGestureDetector(
                        onMatrixUpdate: (m, tm, sm, rm) => item.notifier.value = m,
                        child: AnimatedBuilder(
                          animation: item.notifier,
                          builder: (context, child) => Transform(
                            transform: item.notifier.value,
                            child: GestureDetector(
                              onTap: () => setState(() { 
                                _selectedItem = item; 
                                _isPencilMode = false; 
                              }),
                              child: SizedBox(width: screenWidth, height: screenWidth, child: _buildItemWidget(item)),
                            ),
                          ),
                        ),
                      ),
                    if (_isPencilMode)
                      GestureDetector(
                        onPanUpdate: (details) => setState(() => _currentPoints.add(details.localPosition)),
                        onPanEnd: (details) {
                          if (_currentPoints.isNotEmpty) {
                            setState(() {
                              final newPath = DrawingPath(List.from(_currentPoints))..width = 5.0; 
                              _activeItems.add(newPath);
                              _selectedItem = newPath;
                              _currentPoints.clear();
                            });
                          }
                        },
                        child: CustomPaint(size: Size.infinite, painter: FreehandPainter(_currentPoints, Colors.yellow, 5.0)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(flex: 1),

          // 2. 個別調整パネル
          if (_selectedItem != null)
            Container(
              color: Colors.red[900],
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(children: [
                const Text('太さ', style: TextStyle(color: Colors.white, fontSize: 10)),
                Expanded(child: Slider(value: _selectedItem!.width, min: 0, max: 30, activeColor: Colors.white,
                    onChanged: (val) => setState(() => _selectedItem!.width = val))),
                IconButton(icon: Icon(Icons.color_lens, color: _selectedItem!.color), onPressed: _showColorPicker),
                // ゴミ箱ボタン：これで選択した線や写真を消せます
                IconButton(icon: const Icon(Icons.delete, color: Colors.white), 
                    onPressed: () => setState(() { _activeItems.remove(_selectedItem); _selectedItem = null; })),
              ]),
            ),

          // 3. 切り抜きストックエリア
          if (_savedParts.isNotEmpty)
            Container(
              height: 90,
              color: Colors.grey[900],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _savedParts.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => setState(() {
                    _activeItems.add(_savedParts[index]);
                    _selectedItem = _savedParts[index];
                  }),
                  onLongPress: () => setState(() => _savedParts.removeAt(index)),
                  child: Container(
                    width: 70, margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 2)),
                    child: Image.file(_savedParts[index].imageFile, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),

          // 4. 下部メニュー
          Container(
            color: Colors.black,
            padding: const EdgeInsets.only(bottom: 25, top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildMenuIcon(Icons.content_cut, '切り抜き', _pickImage),
              _buildMenuIcon(Icons.image, '背景(選)', _pickBg),
              _buildMenuIcon(Icons.add_photo_alternate, '背景(自)', _pickCustomBg),
              _buildMenuIcon(_isPencilMode ? Icons.edit : Icons.edit_off, '鉛筆', () {
                setState(() { _isPencilMode = !_isPencilMode; _selectedItem = null; });
              }),
              _buildMenuIcon(_isBgLocked ? Icons.lock : Icons.lock_open, '固定', () => setState(() => _isBgLocked = !_isBgLocked)),
            ]),
          ),
        ],
      ),
    );
  }

  // --- 以下、ロジック ---

  Widget _buildBackground() {
    if (_customBgFile != null) return Image.file(_customBgFile!, fit: BoxFit.contain);
    if (_presetBgAsset != null) return Image.asset(_presetBgAsset!, fit: BoxFit.contain);
    return Container(color: Colors.black45);
  }

  Widget _buildItemWidget(EditableItem item) {
    if (item is CroppedPart) {
      return Stack(children: [
        if (item.width > 0) CustomPaint(painter: PersonaBorderPainter(item.points, item.color, item.width), size: Size.infinite),
        ClipPath(clipper: PersonaClipper(item.points), child: Image.file(item.imageFile, fit: BoxFit.contain)),
      ]);
    } else if (item is DrawingPath) {
      return CustomPaint(painter: FreehandPainter(item.points, item.color, item.width), size: Size.infinite);
    }
    return SizedBox();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CropScreen(image: File(pickedFile.path))));
      if (result != null) {
        setState(() {
          final newPart = CroppedPart(File(pickedFile.path), result);
          _savedParts.add(newPart);
          _activeItems.add(newPart);
          _selectedItem = newPart;
        });
      }
    }
  }

  void _showColorPicker() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('色を選択'),
      content: SingleChildScrollView(child: ColorPicker(pickerColor: _selectedItem!.color, 
        onColorChanged: (color) => setState(() => _selectedItem!.color = color))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('決定'))],
    ));
  }

  Future<void> _exportImage() async {
    try {
      RenderRepaintBoundary? boundary = _saveKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) { await Gal.putImageBytes(byteData.buffer.asUint8List());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました！'))); }
    } catch (e) { print(e); }
  }

  Widget _buildMenuIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 24),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
    ]));
  }

  Future<void> _pickBg() async {
    final selected = await Navigator.push(context, MaterialPageRoute(builder: (context) => BackgroundPickerScreen()));
    if (selected != null) setState(() { _presetBgAsset = selected; _customBgFile = null; _bgNotifier.value = Matrix4.identity(); });
  }

  Future<void> _pickCustomBg() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() { _customBgFile = File(pickedFile.path); _presetBgAsset = null; _bgNotifier.value = Matrix4.identity(); });
    }
  }
}

// --- 描画クラス ---

class FreehandPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double width;
  FreehandPainter(this.points, this.color, this.width);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) { canvas.drawLine(points[i], points[i + 1], paint); }
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class PersonaBorderPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double width;
  PersonaBorderPainter(this.points, this.color, this.width);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || width <= 0) return;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = width..strokeJoin = StrokeJoin.miter;
    final path = Path()..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (var p in points) path.lineTo(p.dx * size.width, p.dy * size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PersonaClipper extends CustomClipper<Path> {
  final List<Offset> normalizedPoints;
  PersonaClipper(this.normalizedPoints);
  @override
  Path getClip(Size size) {
    final path = Path();
    if (normalizedPoints.isNotEmpty) {
      path.moveTo(normalizedPoints.first.dx * size.width, normalizedPoints.first.dy * size.height);
      for (var p in normalizedPoints) path.lineTo(p.dx * size.width, p.dy * size.height);
      path.close();
    }
    return path;
  }
  @override bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}