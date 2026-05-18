import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MaterialApp(home: PersonaCutInPage()));
}

class PersonaCutInPage extends StatefulWidget {
  const PersonaCutInPage({super.key});

  @override
  State<PersonaCutInPage> createState() => _PersonaCutInPageState();
}

class _PersonaCutInPageState extends State<PersonaCutInPage> {
  late VideoPlayerController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // パス設定
  final String _userImagePath = "assets/images/user_cropped.png";
  final String _videoPath = "assets/videos/cutin_air.webm";
  final String _soundPath = "sounds/cutin_se.wav";

  @override
  void initState() {
    super.initState();
    // 動画の初期化処理
    _controller = VideoPlayerController.asset(_videoPath)
      ..initialize().then((_) {
        setState(() {});
        // ループをオフにして1回ごとに制御する
        _controller.setLooping(false);
      });
  }

  // --- この関数がクラスの「中」にあることが重要です ---
  void _playCutIn() {
    // 1. 動画を0秒に戻してから再生（キレを出す）
    _controller.seekTo(Duration.zero).then((_) {
      _controller.play();
    });
    
    // 2. 音を最初から鳴らす（シンクロさせる）
    _audioPlayer.stop().then((_) {
      _audioPlayer.play(
        AssetSource(_soundPath), 
        mode: PlayerMode.lowLatency // 低遅延モードでリズムを一定にする
      );
    });

    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 【1層目】底：赤い背景
          Container(
            color: const Color(0xFFD32F2F),
            width: double.infinity,
            height: double.infinity,
          ),

          // 【2層目】中：キャラクター写真（枠の下に配置）
          Transform.rotate(
            angle: -0.1,
            child: Image.asset(
              _userImagePath,
              width: 280,
              errorBuilder: (context, error, stackTrace) => const Text("画像エラー"),
            ),
          ),

          // 【3層目】表：動く枠（マトリックスで黒を透過）
          if (_controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    1, 0, 0, 0, 0,
                    0, 1, 0, 0, 0,
                    0, 0, 1, 0, 0,
                    1, 1, 1, 0, -255, 
                  ]),
                  child: VideoPlayer(_controller),
                ),
              ),
            ),

          // 【4層目】最前面：スタートボタン
          Positioned(
            bottom: 50,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _playCutIn, // ここで関数を呼び出す
              child: const Icon(Icons.play_arrow, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}