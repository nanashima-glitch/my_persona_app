import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// --- ここから差し替え ---

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
    // 透過動画 (cutin_air.mov) を読み込み
    _controller = VideoPlayerController.asset('assets/videos/cutin_gb.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      }).catchError((e) => print("動画読み込みエラー: $e"));
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
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text("動画プレビュー"),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 【背面】ユーザーが調整したキャラ写真
          IgnorePointer(
            child: Transform.translate(
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
          ),

          // 2. 【前面】透過済みカットイン動画 (cutin_air.mov)
          if (_controller.value.isInitialized)
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 230,
                child: VideoPlayer(_controller),
              ),
            ),
        ],
      ),
    );
  }
} // ← ここでちゃんと _CutInVideoPreviewState が閉じています

// ここからクリッパー（独立したクラス）
class LassoClipper extends CustomClipper<Path> {
  final List<Offset> points;
  LassoClipper(this.points);

  @override
  Path getClip(Size size) {
    var path = Path();
    path.addPolygon(points, true);
    return path;
  }

  @override
  bool shouldReclip(LassoClipper old) => true;
}