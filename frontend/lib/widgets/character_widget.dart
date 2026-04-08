// ไฟล์: lib/screens/character_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:provider/provider.dart';
import '../config/rive_cache.dart';
import '../config/user_pose_provider.dart';
import '../api_service.dart';

class CharacterWidget extends StatefulWidget {
  final double height;
  final double width;
  final User? user;

  const CharacterWidget({
    super.key,
    this.height = 500,
    this.width = 400,
    this.user,
  });

  @override
  State<CharacterWidget> createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget>
    with SingleTickerProviderStateMixin {
  StateMachineController? _controller;
  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMITrigger? _tapInput;
  SMINumber? _skinInput;
  SMINumber? _faceInput;
  SMINumber? _clothInput;
  bool _isRiveLoaded = false;

  // --- Speech Bubble State ---
  String? _greetingText;
  bool _showBubble = false;
  bool _isFetchingGreeting = false; // debounce flag
  Timer? _bubbleTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  // แสดง Speech Bubble พร้อมดึงคำทักทายจาก AI
  Future<void> _showGreeting() async {
    // Debounce: ถ้ากำลังโหลดหรือ bubble แสดงอยู่ → ไม่ทำอะไร
    if (_isFetchingGreeting || _showBubble) return;

    setState(() => _isFetchingGreeting = true);

    final greeting = await ApiService.generateGreeting();

    if (!mounted) return;

    setState(() {
      _greetingText = greeting ?? 'สวัสดีจ้า! 👋';
      _showBubble = true;
      _isFetchingGreeting = false;
    });

    _fadeController.forward();

    // ซ่อน bubble อัตโนมัติหลัง 4 วินาที
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _fadeController.reverse().then((_) {
        if (mounted) setState(() => _showBubble = false);
      });
    });
  }

  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );
    if (controller == null && artboard.stateMachines.isNotEmpty) {
      controller = StateMachineController.fromArtboard(
        artboard,
        artboard.stateMachines.first.name,
      );
    }

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;

      _poseInput = controller.findInput<SMINumber>('Pose') as SMINumber?;

      var hairInputRaw = controller.inputs.firstWhere(
        (e) => e.name == 'HairID',
        orElse: () => controller!.inputs.first,
      );
      if (hairInputRaw is SMINumber && hairInputRaw.name == 'HairID') {
        _hairInput = hairInputRaw;
      }

      var tapInputRaw = controller.inputs.firstWhere(
        (e) => e.name == 'Tapcharacter',
        orElse: () => controller!.inputs.first,
      );
      if (tapInputRaw is SMITrigger && tapInputRaw.name == 'Tapcharacter') {
        _tapInput = tapInputRaw;
      }

      var faceInputRaw = controller.inputs.firstWhere(
        (e) => e.name == 'FaceID',
        orElse: () => controller!.inputs.first,
      );
      if (faceInputRaw is SMINumber && faceInputRaw.name == 'FaceID')
        _faceInput = faceInputRaw;

      var skinInputRaw = controller.inputs.firstWhere(
        (e) => e.name == 'SkinID',
        orElse: () => controller!.inputs.first,
      );
      if (skinInputRaw is SMINumber && skinInputRaw.name == 'SkinID')
        _skinInput = skinInputRaw;

      var clothInputRaw = controller.inputs.firstWhere(
        (e) => e.name == 'ClothID' || e.name == 'BodyID',
        orElse: () => controller!.inputs.first,
      );
      if (clothInputRaw is SMINumber &&
          (clothInputRaw.name == 'ClothID' || clothInputRaw.name == 'BodyID'))
        _clothInput = clothInputRaw;

      _updateRiveInputs();
    }

    if (mounted) setState(() => _isRiveLoaded = true);
  }

  void _updateRiveInputs() {
    if (widget.user == null) return;

    double parseId(String s) {
      if (s.isEmpty) return 0;
      if (s.contains('_')) {
        try {
          return double.parse(s.split('_').last);
        } catch (_) {}
      }
      if (s.startsWith("Hair Style ")) {
        try {
          return double.parse(s.replaceAll("Hair Style ", ""));
        } catch (_) {}
      }
      try {
        return double.parse(s);
      } catch (_) {
        return 0;
      }
    }

    if (_hairInput != null)
      _hairInput!.value = parseId(widget.user!.equippedHair);
    if (_faceInput != null)
      _faceInput!.value = parseId(widget.user!.equippedFace);
    if (_skinInput != null)
      _skinInput!.value = parseId(widget.user!.equippedSkin);
    if (_clothInput != null)
      _clothInput!.value = parseId(widget.user!.equippedCloth);
  }

  @override
  Widget build(BuildContext context) {
    final emotionIndex = context.select<UserPoseProvider, double>(
      (p) => p.currentEmotion,
    );
    if (_poseInput != null && _poseInput!.value != emotionIndex) {
      _poseInput!.value = emotionIndex;
    }

    final shouldTrigger = context.select<UserPoseProvider, bool>(
      (p) => p.shouldTriggerReaction,
    );
    if (shouldTrigger && _tapInput != null) {
      _tapInput!.fire();
    }

    _updateRiveInputs();

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Loading Indicator
          if (!_isRiveLoaded) const CircularProgressIndicator(),

          // Rive Animation
          if (RiveCache().file != null)
            RiveAnimation.direct(
              RiveCache().file!,
              fit: BoxFit.contain,
              antialiasing: false,
              onInit: _onRiveInit,
            )
          else
            RiveAnimation.asset(
              'assets/animation/Model2.0.riv',
              fit: BoxFit.contain,
              antialiasing: false,
              onInit: _onRiveInit,
            ),

          // Speech Bubble — แสดงเหนือตัวละคร
          if (_showBubble && _greetingText != null)
            Positioned(
              top: 20,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _SpeechBubble(text: _greetingText!),
              ),
            ),

          // Loading indicator เล็กๆ ขณะโหลดคำพูด
          if (_isFetchingGreeting)
            Positioned(
              top: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),

          // Tap Area → เปิด Speech Bubble + Rive animation
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                context.read<UserPoseProvider>().triggerReaction();
                _showGreeting(); // เรียก AI
              },
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Speech Bubble Widget ---
class _SpeechBubble extends StatelessWidget {
  final String text;

  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3D2B1F),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final bubbleHeight = size.height - 14; // เว้นที่สำหรับหาง
    final radius = Radius.circular(18);
    final rect = RRect.fromLTRBR(0, 0, size.width, bubbleHeight, radius);

    // Shadow
    canvas.drawRRect(rect.shift(const Offset(0, 3)), shadowPaint);
    // Bubble body
    canvas.drawRRect(rect, paint);

    // หาง bubble ชี้ลงตรงกลาง
    final tailPaint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(size.width / 2 - 12, bubbleHeight - 1)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width / 2 + 12, bubbleHeight - 1)
      ..close();
    canvas.drawPath(path, tailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
