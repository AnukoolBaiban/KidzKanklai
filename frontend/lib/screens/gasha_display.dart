import 'dart:math';
import 'package:flutter/material.dart';

class GashaDisplayScreen extends StatefulWidget {
  final Map<String, dynamic>? gachaResult;
  
  const GashaDisplayScreen({super.key, this.gachaResult});

  @override
  State<GashaDisplayScreen> createState() => _GashaDisplayScreenState();
}

// ระยะของ animation
enum _Phase { idle, shake, reveal }
enum _GachaTheme { blue, gold, rainbow }

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

  // สีธีม
  _GachaTheme _gachaTheme = _GachaTheme.blue;

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
    
    // ตั้งค่าธีมตาม Rarity
    final itemData = widget.gachaResult?['item'] ?? {};
    final rarity = itemData['rarity'] ?? 'COMMON';
    
    if (rarity == 'EPIC') {
      _gachaTheme = _GachaTheme.rainbow;
    } else if (rarity == 'RARE') {
      _gachaTheme = _GachaTheme.gold;
    } else {
      _gachaTheme = _GachaTheme.blue;
    }

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
  // สี theme (ฟ้า → ทอง หรือ สีรุ้ง แบบ smooth lerp)
  // ──────────────────────────────────────────
  double get _t {
    if (_phase == _Phase.idle) return 0.0;
    return _gachaTheme != _GachaTheme.blue ? _themeProgress.value : 0.0;
  }

  Color get _bgGradientEnd {
    if (_phase == _Phase.idle || _gachaTheme == _GachaTheme.blue) return _kBlueBgEnd;
    if (_gachaTheme == _GachaTheme.gold) {
      return Color.lerp(_kBlueBgEnd, _kGoldBgEnd, _themeProgress.value)!;
    }
    return Color.lerp(_kBlueBgEnd, const Color(0xFFF0E6FF), _themeProgress.value)!;
  }

  Color get _flashColor {
    if (_phase == _Phase.idle || _gachaTheme == _GachaTheme.blue) return _kBlueFlash;
    if (_gachaTheme == _GachaTheme.gold) {
      return Color.lerp(_kBlueFlash, _kGoldFlash, _themeProgress.value)!;
    }
    return Color.lerp(_kBlueFlash, Colors.white, _themeProgress.value)!;
  }

  BoxDecoration get _topBarDecoration {
    if (_phase == _Phase.idle || _gachaTheme == _GachaTheme.blue) {
      return const BoxDecoration(color: _kBlueBgTop);
    }
    if (_gachaTheme == _GachaTheme.gold) {
      return BoxDecoration(
        color: Color.lerp(_kBlueBgTop, _kGoldBgTop, _themeProgress.value)!,
      );
    }
    
    final t = _frameController.value;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.lerp(_kBlueBgTop, const Color(0xFFFFB3BA), _themeProgress.value)!,
          Color.lerp(_kBlueBgTop, const Color(0xFFFFDFBA), _themeProgress.value)!,
          Color.lerp(_kBlueBgTop, const Color(0xFFFFFFBA), _themeProgress.value)!,
          Color.lerp(_kBlueBgTop, const Color(0xFFBAFFC9), _themeProgress.value)!,
          Color.lerp(_kBlueBgTop, const Color(0xFFBAE1FF), _themeProgress.value)!,
          Color.lerp(_kBlueBgTop, const Color(0xFFD0BAFF), _themeProgress.value)!,
          Color.lerp(_kBlueBgTop, const Color(0xFFFFB3BA), _themeProgress.value)!,
        ],
        stops: const [0.0, 0.166, 0.333, 0.5, 0.666, 0.833, 1.0],
        begin: Alignment(-1.0 + (t * 2.0), 0.0),
        end: Alignment(1.0 + (t * 2.0), 0.0),
        tileMode: TileMode.repeated,
      ),
    );
  }

  BoxDecoration get _stripeDecoration {
    if (_phase == _Phase.idle || _gachaTheme == _GachaTheme.blue) {
      return const BoxDecoration(color: _kBlueBgStripe);
    }
    if (_gachaTheme == _GachaTheme.gold) {
      return BoxDecoration(
        color: Color.lerp(_kBlueBgStripe, _kGoldBgStripe, _themeProgress.value)!,
      );
    }

    final t = _frameController.value;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.lerp(_kBlueBgStripe, const Color(0xFFFFB3BA), _themeProgress.value)!,
          Color.lerp(_kBlueBgStripe, const Color(0xFFFFDFBA), _themeProgress.value)!,
          Color.lerp(_kBlueBgStripe, const Color(0xFFFFFFBA), _themeProgress.value)!,
          Color.lerp(_kBlueBgStripe, const Color(0xFFBAFFC9), _themeProgress.value)!,
          Color.lerp(_kBlueBgStripe, const Color(0xFFBAE1FF), _themeProgress.value)!,
          Color.lerp(_kBlueBgStripe, const Color(0xFFD0BAFF), _themeProgress.value)!,
          Color.lerp(_kBlueBgStripe, const Color(0xFFFFB3BA), _themeProgress.value)!,
        ],
        stops: const [0.0, 0.166, 0.333, 0.5, 0.666, 0.833, 1.0],
        begin: Alignment(-1.0 + (t * 2.0), 0.0),
        end: Alignment(1.0 + (t * 2.0), 0.0),
        tileMode: TileMode.repeated,
      ),
    );
  }

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
              Container(height: topBarH, decoration: _topBarDecoration),
              Container(height: stripeH, decoration: _stripeDecoration),
            ],
          ),
        ),
        Positioned(
          top: topBarH + stripeH + 10,
          left: 20 + (oscillation * 15),
          child: Container(
            width: size.width * 0.4,
            height: stripeH * 0.6,
            decoration: _stripeDecoration,
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
              Container(height: stripeH, decoration: _stripeDecoration),
              Container(height: bottomBarH, decoration: _topBarDecoration),
            ],
          ),
        ),
        Positioned(
          bottom: bottomBarH + stripeH + 10,
          right: 20 - (oscillation * 15),
          child: Container(
            width: size.width * 0.4,
            height: stripeH * 0.6,
            decoration: _stripeDecoration,
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
                    color: _kBlueBorder,
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
    final itemWidth = size.width * 0.7 > 300.0 ? 300.0 : size.width * 0.7;
    final titleSize = size.width * 0.07 > 28.0 ? 28.0 : size.width * 0.07;
    
    // อ่านข้อมูลจาก API result
    final itemData = widget.gachaResult?['item'] ?? {};
    final isDuplicate = widget.gachaResult?['is_duplicate'] ?? false;
    final coinReward = widget.gachaResult?['coin_reward'] ?? 0;
    
    final itemName = itemData['name'] ?? 'EXP';
    final itemDescription = itemData['description'] ?? itemName;
    final int categoryId = itemData['category_id'] ?? 0;
    
    String itemImage = 'assets/images/item/EXP.png';
    if (categoryId == 10) {
      itemImage = 'assets/images/Fashion/Outfit/$itemName.PNG';
    } else if (categoryId == 12) {
      itemImage = 'assets/images/Fashion/HairStyle/$itemName.PNG';
    } else if (categoryId == 13) {
      itemImage = 'assets/images/Fashion/FaceStyle/$itemName.PNG';
    }

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 0),
        child: Transform.scale(
          scale: _itemScale.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── ป้าย "ไอเทมใหม่" หรือ "ได้เหรียญคืน" ──
              if (isDuplicate) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'มีแฟชั่นนี้อยู่แล้ว! แปลงเป็น ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$coinReward ',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Image.asset(
                        'assets/images/item/coin.png',
                        width: 20,
                        errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on, color: Colors.yellow, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
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
                    'แฟชั่นใหม่',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── รูปไอเทมพร้อมแสงออร่า (อลังการแบบมินิมอล) ──
              SizedBox(
                width: itemWidth,
                height: itemWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [


                    // เอฟเฟคดาววิบวับ (Twinkling Stars) สำหรับทุกระดับ
                    Positioned.fill(
                      child: OverflowBox(
                        maxWidth: itemWidth * 1.8,
                        maxHeight: itemWidth * 1.8,
                        child: AnimatedBuilder(
                          animation: _frameController,
                          builder: (context, child) {
                            final t = _frameController.value;
                            
                            Widget buildStar(double angle, double distanceFraction, double offset, double size) {
                              final time = (t + offset) % 1.0;
                              final pulse = sin(time * pi); // 0 -> 1 -> 0
                              
                              final distance = (itemWidth / 2) * distanceFraction;
                              final dx = cos(angle) * distance;
                              final dy = sin(angle) * distance;

                              return Transform.translate(
                                offset: Offset(dx, dy),
                                child: Transform.scale(
                                  scale: pulse,
                                  child: Opacity(
                                    opacity: pulse * 0.8,
                                    child: Icon(
                                      Icons.star_rounded,
                                      color: const Color(0xFFFFD54F),
                                      size: size,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                buildStar(0.5, 0.9, 0.0, 16),
                                buildStar(2.0, 1.1, 0.3, 24),
                                buildStar(3.5, 0.8, 0.6, 12),
                                buildStar(5.0, 1.2, 0.2, 20),
                                buildStar(1.2, 1.3, 0.8, 14),
                                buildStar(4.2, 1.0, 0.5, 18),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    
                    // รูปไอเทมหลัก
                    Image.asset(
                      itemImage,
                      width: itemWidth,
                      height: itemWidth,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.star_rounded,
                        size: itemWidth * 0.7,
                        color: _kBlueBorder,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── ชื่อไอเทม ──
              Text(
                itemDescription,
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