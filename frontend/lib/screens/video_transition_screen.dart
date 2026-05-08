import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoTransitionScreen extends StatefulWidget {
  final String videoPath;

  const VideoTransitionScreen({Key? key, required this.videoPath}) : super(key: key);

  @override
  State<VideoTransitionScreen> createState() => _VideoTransitionScreenState();
}

class _VideoTransitionScreenState extends State<VideoTransitionScreen> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _controller.play();
      });

    // ฟังเมื่อวิดีโอเล่นจบ
    _controller.addListener(() {
      if (_isPopping || !_controller.value.isInitialized) return;

      final position = _controller.value.position;
      final duration = _controller.value.duration;

      // เช็คว่าเล่นจบหรือยัง (เว้นช่วงเผื่อบัคของแพลตฟอร์มบางทีมันเล่นไม่ถึง duration เป๊ะๆ)
      if (position > Duration.zero && position + const Duration(milliseconds: 200) >= duration) {
        _skipVideo();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skipVideo() {
    if (_isPopping) return;
    _isPopping = true;
    if (mounted) {
      Navigator.pop(context, true); // คืนค่า true และปิดหน้าจอ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // พื้นหลังสีดำเวลารอโหลด
      body: GestureDetector(
        onTap: _skipVideo,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Center(
              child: _isVideoInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            
            // ปุ่มบอกให้แตะเพื่อข้าม หรือจะทำเป็น Fade In แบบกาชาก็ได้
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'แตะหน้าจอเพื่อข้าม',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
