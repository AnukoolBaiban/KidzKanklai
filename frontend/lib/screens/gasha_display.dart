import 'dart:math';
import 'package:flutter/material.dart';

class GashaDisplayScreen extends StatefulWidget {
  const GashaDisplayScreen({super.key});

  @override
  State<GashaDisplayScreen> createState() => _GashaDisplayScreenState();
}

// ระยะของ animation
enum _Phase { idle, shake, reveal }

class _GashaDisplayScreenState extends State<GashaDisplayScreen>
    with TickerProviderStateMixin {
  // ───── Controllers ─────
  late AnimationController _idleController;
  late AnimationController _shakeController;
  late AnimationController _revealController;
  late AnimationController _frameController;

  // ───── Animations – Idle ─────
  late Animation<double> _idleBounce;

  // ───── Animations – Shake ─────
  late Animation<double> _shakeRotation;
  late Animation<double> _shakeTranslation;

  // ───── Animations – Reveal ─────
  late Animation<double> _flashAlpha;
  late Animation<double> _itemScale;
  late Animation<double> _textFade;
  late Animation<double> _boxScaleOut;
  late Animation<double> _boxOpacityOut;

  // ───── State ─────
  _Phase _phase = _Phase.idle;
  bool _isAnimationFinished = false;

  // สีธีม: false = ฟ้า (ค่าเริ่มต้น idle), true = ทอง
  // จะสุ่มเมื่อผู้ใช้กดกล่อง ตอน idle ใช้สีฟ้าเสมอ
  bool _isGoldTheme = false;

  late Animation<double> _themeProgress;

  // ── color constants ──
  static const Color _kBlueBorder = Color(0xFF447199);
  static const Color _kBlueBgTop = Color(0xFF447199);
  static const Color _kBlueBgStripe = Color(0xFF9DD0E7);
  static const Color _kBlueBgEnd = Color(0xFFDCF8FF);
  static const Color _kBlueFlash = Colors.white;

  static const Color _kGoldBorder = Color(0xFFE8BD4B);
  static const Color _kGoldBgTop = Color(0xFFE8BD4B);
  static const Color _kGoldBgStripe = Color(0xFFEDDB88);
  static const Color _kGoldBgEnd = Color(0xFFFFF9E6);
  static const Color _kGoldFlash = Color(0xFFFFFDE7);

  @override
  void initState() {
    super.initState();

    _setupIdleController();
    _setupShakeController();
    _setupRevealController();
    _setupFrameController();
    _idleController.repeat(reverse: true);
  }

  // ──────────────────────────────────────────
  // Phase 1: Idle bounce (ขึ้น-ลงเบาๆ)
  // ──────────────────────────────────────────
  void _setupIdleController() {
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _idleBounce = Tween<double>(begin: 0.0, end: -12.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
  }

  // ──────────────────────────────────────────
  // Phase 2: Shake + Glow
  // ──────────────────────────────────────────
  void _setupShakeController() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // การสั่น – rotation
    _shakeRotation =
        TweenSequence<double>([
          for (int i = 0; i < 7; i++) ...[
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 0.0,
                end: 0.09,
              ).chain(CurveTween(curve: Curves.easeOut)),
              weight: 1,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 0.09,
                end: -0.09,
              ).chain(CurveTween(curve: Curves.easeInOut)),
              weight: 2,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: -0.09,
                end: 0.0,
              ).chain(CurveTween(curve: Curves.easeIn)),
              weight: 1,
            ),
          ],
        ]).animate(
          CurvedAnimation(
            parent: _shakeController,
            curve: const Interval(0.0, 0.75),
          ),
        );

    // การสั่น – translation X
    _shakeTranslation =
        TweenSequence<double>([
          for (int i = 0; i < 7; i++) ...[
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 0.0,
                end: 9.0,
              ).chain(CurveTween(curve: Curves.easeOut)),
              weight: 1,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 9.0,
                end: -9.0,
              ).chain(CurveTween(curve: Curves.easeInOut)),
              weight: 2,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: -9.0,
                end: 0.0,
              ).chain(CurveTween(curve: Curves.easeIn)),
              weight: 1,
            ),
          ],
        ]).animate(
          CurvedAnimation(
            parent: _shakeController,
            curve: const Interval(0.0, 0.75),
          ),
        );

    // Color transition: เริ่ม lerp สีที่ 30% ของ shake → จบที่ 90%
    // ทำให้ผู้ใช้เห็นกล่องสั่นก่อนสักครู่ แล้วสีค่อยๆ เปลี่ยน
    _themeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: const Interval(0.30, 0.90, curve: Curves.easeInOut),
      ),
    );

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startReveal();
      }
    });
  }

  // ──────────────────────────────────────────
  // Phase 3: Reveal (flash + ไอเทมปรากฏ)
  // ──────────────────────────────────────────
  void _setupRevealController() {
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // แสง
    _flashAlpha =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 3,
          ),
          TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 2),
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.0,
              end: 0.0,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 4,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _revealController,
            curve: const Interval(0.0, 0.60),
          ),
        );

    // ไอเทมเด้งขึ้น
    _itemScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOutBack),
      ),
    );

    // เลือนกล่องกาชาออกตอนที่โดนแสงสว่างวาบกลบ
    _boxScaleOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.20, curve: Curves.easeInBack),
      ),
    );
    _boxOpacityOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.20, curve: Curves.linear),
      ),
    );

    // ข้อความ "แตะเพื่อไปต่อ"
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );

    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _isAnimationFinished = true);
      }
    });
  }

  // ──────────────────────────────────────────
  // กรอบตกแต่ง (oscillation loop)
  // ──────────────────────────────────────────
  void _setupFrameController() {
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _idleController.dispose();
    _shakeController.dispose();
    _revealController.dispose();
    _frameController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  // การกด: กล่อง → เริ่ม shake
  // ──────────────────────────────────────────
  void _onBoxTap() {
    if (_phase != _Phase.idle) return;
    // สุ่มธีมสี ณ เวลาที่ผู้ใช้กดกล่อง (ฟ้าหรือทอง)
    _isGoldTheme = Random().nextBool();
    setState(() => _phase = _Phase.shake);
    _idleController.stop();
    _shakeController.forward(from: 0.0);
  }

  // ──────────────────────────────────────────
  // เริ่ม reveal
  // ──────────────────────────────────────────
  void _startReveal() {
    if (!mounted) return;
    setState(() => _phase = _Phase.reveal);
    _revealController.forward(from: 0.0);
  }

  // แตะหน้าจอเพื่อข้ามหรือออก
  void _skipOrClose() {
    if (_phase == _Phase.idle) return; // ไม่ให้ข้ามตอน idle
    if (!_isAnimationFinished) {
      _revealController.value = 1.0;
    } else {
      Navigator.pop(context);
    }
  }

  // ──────────────────────────────────────────
  // สี theme (ฟ้า → ทอง แบบ smooth lerp)
  // ──────────────────────────────────────────
  double get _t {
    if (_phase == _Phase.idle) return 0.0;
    return _isGoldTheme ? _themeProgress.value : 0.0;
  }

  Color get _borderColor => Color.lerp(_kBlueBorder, _kGoldBorder, _t)!;
  Color get _bgTop => Color.lerp(_kBlueBgTop, _kGoldBgTop, _t)!;
  Color get _bgStripe => Color.lerp(_kBlueBgStripe, _kGoldBgStripe, _t)!;
  Color get _bgGradientEnd => Color.lerp(_kBlueBgEnd, _kGoldBgEnd, _t)!;
  Color get _flashColor => Color.lerp(_kBlueFlash, _kGoldFlash, _t)!;

  // ──────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _skipOrClose,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _idleController,
            _shakeController,
            _revealController,
            _frameController,
          ]),
          builder: (context, child) {
            final bool showBox = _phase != _Phase.reveal;
            final bool showItem =
                _phase == _Phase.reveal && _revealController.value >= 0.35;

            return Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  _buildTopFramework(context),
                  _buildBottomFramework(context),
                  if (showBox) _buildBox(context),
                  if (showItem) _buildItem(context),
                  _buildFlashEffect(),
                  _buildTextOverlay(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── กรอบตกแต่งด้านบน ────────────────────
  Widget _buildTopFramework(BuildContext context) {
    final double oscillation = sin(_frameController.value * 2 * pi);
    final size = MediaQuery.sizeOf(context);
    final topBarH = size.height * 0.1 > 75.0 ? 75.0 : size.height * 0.1;
    final stripeH = topBarH * 0.2;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(height: topBarH, color: _bgTop),
              Container(height: stripeH, color: _bgStripe),
            ],
          ),
        ),
        Positioned(
          top: topBarH + stripeH + 10,
          left: 20 + (oscillation * 15),
          child: Container(
            width: size.width * 0.4,
            height: stripeH * 0.6,
            color: _bgStripe,
          ),
        ),
      ],
    );
  }

  // ── กรอบตกแต่งด้านล่าง ───────────────────
  Widget _buildBottomFramework(BuildContext context) {
    final double oscillation = sin(_frameController.value * 2 * pi);
    final size = MediaQuery.sizeOf(context);
    final bottomBarH = size.height * 0.1 > 75.0 ? 75.0 : size.height * 0.1;
    final stripeH = bottomBarH * 0.2;

    return Stack(
      children: [
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: stripeH, color: _bgStripe),
              Container(height: bottomBarH, color: _bgTop),
            ],
          ),
        ),
        Positioned(
          bottom: bottomBarH + stripeH + 10,
          right: 20 - (oscillation * 15),
          child: Container(
            width: size.width * 0.4,
            height: stripeH * 0.6,
            color: _bgStripe,
          ),
        ),
      ],
    );
  }

  // ── เอฟเฟคแสงสว่าง (Flash) ────────────
  Widget _buildFlashEffect() {
    if (_phase != _Phase.reveal || _flashAlpha.value <= 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              _flashColor.withValues(alpha: min(1.0, _flashAlpha.value * 1.5)),
              _bgGradientEnd.withValues(
                alpha: min(1.0, _flashAlpha.value * 1.2),
              ),
              _bgGradientEnd.withValues(alpha: 0.0),
            ],
            stops: [0.0, min(1.0, _flashAlpha.value * 0.8), 1.0],
            radius: max(0.01, _flashAlpha.value * 2.5),
          ),
        ),
      ),
    );
  }

  // ── ข้อความแนะนำด้านล่าง (Text Overlay) ─────
  Widget _buildTextOverlay(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomOffset = size.height * 0.18 > 140.0
        ? 140.0
        : size.height * 0.18;

    if (_isAnimationFinished) {
      return Positioned(
        bottom: bottomOffset,
        left: 0,
        right: 0,
        child: FadeTransition(
          opacity: _textFade,
          child: Center(
            child: Text(
              'แตะหน้าจอเพื่อดำเนินการต่อ',
              style: const TextStyle(
                color: Color(0xFF313131),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    } else if (_phase == _Phase.idle) {
      return Positioned(
        bottom: bottomOffset,
        left: 0,
        right: 0,
        child: const Center(
          child: Text(
            'กดที่กล่องเพื่อเปิด!',
            style: TextStyle(
              color: Color(0xFF313131),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ──────────────────────────────────────────
  // Widget: กล่องกาชา
  // ──────────────────────────────────────────
  Widget _buildBox(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final boxWidth = size.width * 0.6 > 250.0 ? 250.0 : size.width * 0.6;
    final iconSize = boxWidth * 0.6;
    final double bounceY = _phase == _Phase.idle ? _idleBounce.value : 0.0;
    final double shakeX = _phase == _Phase.shake
        ? _shakeTranslation.value
        : 0.0;
    final double shakeAngle = _phase == _Phase.shake
        ? _shakeRotation.value
        : 0.0;
    final double currentBoxScale = _phase == _Phase.reveal
        ? _boxScaleOut.value
        : 1.0;
    final double currentBoxOpacity = _phase == _Phase.reveal
        ? _boxOpacityOut.value
        : 1.0;

    return Center(
      child: GestureDetector(
        onTap: _onBoxTap,
        child: Transform.translate(
          offset: Offset(shakeX, bounceY),
          child: Transform.rotate(
            angle: shakeAngle,
            child: Transform.scale(
              scale: currentBoxScale,
              child: Opacity(
                opacity: currentBoxOpacity,
                child: Image.asset(
                  'assets/images/item/Gasha.png',
                  width: boxWidth,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.card_giftcard,
                    size: iconSize,
                    color: _borderColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Widget: ไอเทมที่ได้รับ
  // ──────────────────────────────────────────
  Widget _buildItem(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final itemWidth = size.width * 0.5 > 200.0 ? 200.0 : size.width * 0.5;
    final titleSize = size.width * 0.07 > 28.0 ? 28.0 : size.width * 0.07;
    // กำหนดข้อมูลไอเทม (สามารถเปลี่ยนเป็นตัวแปรแบบ dynamic ได้ในอนาคต)
    final bool isNewItem = true;
    final String itemImage = 'assets/images/item/EXP.png';
    final String itemName = 'EXP';

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 0),
        child: Transform.scale(
          scale: _itemScale.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── ป้าย "ไอเทมใหม่" ──
              if (isNewItem) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF313131),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'ใหม่',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── รูปไอเทม ──
              Image.asset(
                itemImage,
                width: itemWidth,
                height: itemWidth,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.star_rounded,
                  size: itemWidth * 0.7,
                  color: const Color(0xFF313131),
                ),
              ),

              const SizedBox(height: 16),

              // ── ชื่อไอเทม ──
              Text(
                itemName,
                style: TextStyle(
                  color: const Color(0xFF313131),
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}