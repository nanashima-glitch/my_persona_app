import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

// --- エディタ画面 ---
class CutInEditor extends StatefulWidget {
  const CutInEditor({super.key});
  @override
  _CutInEditorState createState() => _CutInEditorState();
}

class _CutInEditorState extends State<CutInEditor> {
  File? _rawImage;
  List<Offset>? _clippedPoints;
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  double _rotation = 0.0;
  bool _isFrameVisible = true;

  Future<void> _startProcess() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final List<Offset>? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LassoCropScreen(imageFile: File(file.path))),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _rawImage = File(file.path);
        _clippedPoints = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // 真っ黒より少し明るいグレーにすると境目が見やすい
      appBar: AppBar(title: const Text("配置・角度の調整"), backgroundColor: Colors.red[900]),
      body: Stack(
        children: [
          // キャラの配置エリア
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_rawImage != null && _clippedPoints != null)
                  Transform.translate(
                    offset: _offset,
                    child: Transform.rotate(
                      angle: _rotation,
                      child: Transform.scale(
                        scale: _scale,
                        child: ClipPath(
                          clipper: LassoClipper(_clippedPoints!),
                          child: Image.file(_rawImage!),
                        ),
                      ),
                    ),
                  ),
                // 枠の表示（背景を透過させるため opacity を調整）
                if (_isFrameVisible)
                  IgnorePointer(
                    child: Opacity(
                      opacity: 0.7, // 枠を半透明にしてキャラを見やすくする
                      child: Image.asset(
                        'assets/images/cutin_frame_red.png',
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_rawImage != null)
            GestureDetector(
              onScaleUpdate: (d) {
                setState(() {
                  _scale *= d.scale;
                  _rotation += d.rotation;
                  _offset += d.focalPointDelta;
                });
              },
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.red[900],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: _startProcess, child: const Text("写真を選ぶ")),
            IconButton(
              icon: Icon(_isFrameVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white),
              onPressed: () => setState(() => _isFrameVisible = !_isFrameVisible),
            ),
            if (_rawImage != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CutInVideoPreview(
                    userPhoto: _rawImage!,
                    clipPath: _clippedPoints!,
                    position: _offset,
                    scale: _scale,
                    rotation: _rotation,
                  )));
                },
                child: const Text("動画プレビュー"),
              ),
          ],
        ),
      ),
    );
  }
}

// --- 動画プレビュー画面 ---
class CutInVideoPreview extends StatefulWidget {
  final File userPhoto;
  final List<Offset> clipPath;
  final Offset position;
  final double scale;
  final double rotation;

  const CutInVideoPreview({
    super.key,
    required this.userPhoto,
    required this.clipPath,
    required this.position,
    required this.scale,
    required this.rotation,
  });

  @override
  _CutInVideoPreviewState createState() => _CutInVideoPreviewState();
}

class _CutInVideoPreviewState extends State<CutInVideoPreview> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // ffmpegで書き出した赤い動画
    _controller = VideoPlayerController.asset('assets/videos/cutin_gb.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.red[900], title: const Text("動画プレビュー")),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 【背面】切り抜いたキャラ
          if (_controller.value.isInitialized)
            Transform.translate(
              offset: widget.position,
              child: Transform.rotate(
                angle: widget.rotation,
                child: Transform.scale(
                  scale: widget.scale,
                  child: ClipPath(
                    clipper: LassoClipper(widget.clipPath),
                    child: Image.file(widget.userPhoto),
                  ),
                ),
              ),
            ),
          
          // 2. 【前面】動画（ブレンドモードを使って黒を消す）
          if (_controller.value.isInitialized)
            IgnorePointer(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    // 「スクリーン」ブレンドに近い効果で、黒を透明化し赤と白を残す
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        1, 0, 0, 0, 0,
                        0, 1, 0, 0, 0,
                        0, 0, 1, 0, 0,
                        0.33, 0.33, 0.33, 1, -100, // アルファ計算を調整
                      ]),
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- なぞる画面（変更なし） ---
class LassoCropScreen extends StatefulWidget {
  final File imageFile;
  const LassoCropScreen({super.key, required this.imageFile});
  @override
  State<LassoCropScreen> createState() => _LassoCropScreenState();
}

class _LassoCropScreenState extends State<LassoCropScreen> {
  final List<Offset> _points = [];
  final GlobalKey _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("キャラを指でなぞる"), actions: [
        TextButton(onPressed: () => Navigator.pop(context, _points), child: const Text("完了", style: TextStyle(color: Colors.white)))
      ]),
      body: Center(
        child: GestureDetector(
          onPanUpdate: (d) {
            final RenderBox box = _imageKey.currentContext!.findRenderObject() as RenderBox;
            final Offset localPos = box.globalToLocal(d.globalPosition);
            setState(() => _points.add(localPos));
          },
          child: Stack(
            children: [
              Image.file(widget.imageFile, key: _imageKey),
              CustomPaint(painter: LassoPainter(_points), size: Size.infinite),
            ],
          ),
        ),
      ),
    );
  }
}

class LassoPainter extends CustomPainter {
  final List<Offset> points;
  LassoPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()..color = Colors.red..strokeWidth = 3.0..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..addPolygon(points, false), paint);
  }
  @override
  bool shouldRepaint(LassoPainter old) => true;
}

class LassoClipper extends CustomClipper<Path> {
  final List<Offset> points;
  LassoClipper(this.points);
  @override
  Path getClip(Size size) => Path()..addPolygon(points, true);
  @override
  bool shouldReclip(LassoClipper old) => true;
}