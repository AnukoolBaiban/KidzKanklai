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
  final int? overrideLevel;
  final bool isInteractive;

  const CharacterWidget({
    super.key,
    this.height = 500,
    this.width = 400,
    this.user,
    this.overrideLevel,
    this.isInteractive = true,
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
  SMINumber? _armInput;
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
      
      // [DEBUG] Print all available inputs from the Rive file to the terminal
      print("===== RIVE INPUTS FOR \${_getModelAsset()} =====");
      for (var input in controller.inputs) {
        print("- \${input.name} (\${input.runtimeType})");
      }
      print("==========================================");

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
        (e) => e.name == 'OutfitID',
        orElse: () => controller!.inputs.first,
      );
      if (clothInputRaw is SMINumber && clothInputRaw.name == 'OutfitID') {
        _clothInput = clothInputRaw;
      }

      _updateRiveInputs();
    }

    if (mounted) setState(() => _isRiveLoaded = true);
  }

  void _updateRiveInputs() {
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

    double hairVal = widget.user != null ? parseId(widget.user!.equippedHair) : 0.0;
    double faceVal = widget.user != null ? parseId(widget.user!.equippedFace) : 0.0;
    double skinVal = widget.user != null ? parseId(widget.user!.equippedSkin) : 0.0;
    double clothVal = widget.user != null ? parseId(widget.user!.equippedOutfit) : 0.0;

    if (_hairInput != null) _hairInput!.value = hairVal;
    if (_faceInput != null) _faceInput!.value = faceVal;
    if (_skinInput != null) _skinInput!.value = skinVal;
    if (_clothInput != null) _clothInput!.value = clothVal;
    if (_armInput != null) _armInput!.value = clothVal;
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

    final currentLevel = widget.overrideLevel ?? widget.user?.level ?? 1;

    String getModelAsset() {
      // 1. ถ้ามีการระบุ overrideLevel (เช่น ใน Animation วิวัฒนาการ) บังคับใช้ภาพตามเลเวลนี้โดยตรง!
      if (widget.overrideLevel != null) {
        if (widget.overrideLevel! >= 30) return 'assets/animation/adult.riv';
        if (widget.overrideLevel! >= 15) return 'assets/animation/teen.riv';
        return 'assets/animation/kid.riv';
      }

      // 2. ถ้าใช้งานปกติและมีข้อมูล User ให้ใช้ bodyType จาก Database เป็นหลัก (รองรับระบบเลือกร่างวัยรุ่นแม้เลเวล 30)
      if (widget.user != null) {
        final bt = widget.user!.bodyType.toUpperCase();
        if (bt == 'ADULT') return 'assets/animation/adult.riv';
        if (bt == 'TEEN') return 'assets/animation/teen.riv';
        return 'assets/animation/kid.riv';
      }

      // 3. Fallback: ตรวจจับร่างจากเลเวลปัจจุบัน
      if (currentLevel >= 30) return 'assets/animation/adult.riv';
      if (currentLevel >= 15) return 'assets/animation/teen.riv';
      return 'assets/animation/kid.riv';
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Loading Indicator
          if (!_isRiveLoaded) const CircularProgressIndicator(),

          // Rive Animation
          if (RiveCache().getFile(getModelAsset()) != null)
            RiveAnimation.direct(
              RiveCache().getFile(getModelAsset())!,
              fit: BoxFit.contain,
              antialiasing: false,
              onInit: _onRiveInit,
              stateMachines: const ['State Machine 1'],
            )
          else
            RiveAnimation.asset(
              getModelAsset(),
              fit: BoxFit.contain,
              antialiasing: false,
              onInit: _onRiveInit,
              stateMachines: const ['State Machine 1'],
            ),

          // Speech Bubble — แสดงเหนือตัวละคร (ปิดถ้าไม่ได้อยู่ในโหมด Interactive)
          if (widget.isInteractive && _showBubble && _greetingText != null)
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
          if (widget.isInteractive)
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
