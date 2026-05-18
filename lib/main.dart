import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MaterialApp(home: PersonaCutInPage()));
}

class PersonaCutInPage extends StatefulWidget {
  const PersonaCutInPage({super.key});

  @override
  State<PersonaCutInPage> createState() => _PersonaCutInPageState();
}

class _PersonaCutInPageState extends State<PersonaCutInPage> {
  static const platform = MethodChannel('com.example.persona/video_export');
  
  // 以前実装した写真操作用の変数
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  double _rotation = 0.0;
  
  // あなたが使用している写真のアセットパス
  final String _userImagePath = 'assets/images/user_photo.png'; // 自身のパスに合わせてください
  
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // 枠動画の初期化
    _controller = VideoPlayerController.asset('assets/videos/064.webm')
      ..initialize().then((_) {
        setState(() {});
      });
  }

  // --- ここが修正ポイント：保存処理 ---
  Future<void> _exportVideo() async {
    try {
      // 1. アセット画像を一時ファイルに書き出す（Android側で読み込むため）
      final byteData = await rootBundle.load(_userImagePath);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_user_photo.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(
        byteData.offsetInBytes, byteData.lengthInBytes
      ));

      // 2. Android側に配置データを送る
      final String result = await platform.invokeMethod('exportVideo', {
        'imagePath': file.path,
        'scale': _scale,
        'dx': _offset.dx,
        'dy': _offset.dy,
        'rotation': _rotation,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result))
      );
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("失敗: ${e.message}"))
      );
    }
  }

  void _playCutIn() {
    _controller.seekTo(Duration.zero);
    _controller.play();
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
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 背景の赤（プレビュー用）
          Container(color: const Color(0xFFD32F2F)),

          // 2. 操作できる写真
          GestureDetector(
            onScaleUpdate: (details) {
              setState(() {
                _scale = details.scale;
                _offset = details.focalPoint - const Offset(200, 300); // 中心調整
                _rotation = details.rotation;
              });
            },
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(_offset.dx, _offset.dy)
                ..scale(_scale)
                ..rotateZ(_rotation),
              child: Image.asset(_userImagePath, width: 300),
            ),
          ),

          // 3. 上に重ねるWebM枠
          if (_controller.value.isInitialized)
            IgnorePointer(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
          
          // 4. 操作ボタン
          Positioned(
            bottom: 50,
            child: Row(
              children: [
                FloatingActionButton(
                  onPressed: _playCutIn,
                  heroTag: 'play',
                  child: const Icon(Icons.play_arrow),
                ),
                const SizedBox(width: 20),
                FloatingActionButton(
                  onPressed: _exportVideo,
                  heroTag: 'export',
                  child: const Icon(Icons.save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}