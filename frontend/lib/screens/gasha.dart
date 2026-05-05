import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/custom_top_bar.dart';
import 'gasha_display.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/gasha_rate_popup.dart';
import '../widgets/confirm_gasha_popup.dart';
import '../api_service.dart';

class GashaScreen extends StatefulWidget {
  const GashaScreen({super.key});

  @override
  State<GashaScreen> createState() => _GashaScreenState();
}

class _GashaScreenState extends State<GashaScreen> with TickerProviderStateMixin {
  AnimationController? _rainbowController;
  int _selectedIndex = -1; // ไม่ highlight tab ใดเพราะ Gasha ไม่ใช่ main tab
  final int _coins = 2000;
  final int _cost = 2000;

  void _onNavTapped(int index) {
    setState(() => _selectedIndex = index);
    const routes = ['/fashion', '/lobby', '/map', '/club'];
    if (index < routes.length) Navigator.pushNamed(context, routes[index]);
  }

  bool _isLoading = false;
  List<Map<String, dynamic>> _commonItems = [];
  Timer? _commonItemTimer;
  int _currentCommonIndex = 0;

  @override
  void initState() {
    super.initState();
    _rainbowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadCommonItems();
  }

  Future<void> _loadCommonItems() async {
    try {
      final rates = await ApiService.getGachaRates();
      if (mounted) {
        setState(() {
          _commonItems = rates.where((it) => it['rarity'] != 'EPIC' && it['rarity'] != 'RARE').toList();
        });
        
        if (_commonItems.isNotEmpty) {
          _commonItemTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
            if (mounted && _commonItems.isNotEmpty) {
              setState(() {
                _currentCommonIndex = (_currentCommonIndex + 1) % _commonItems.length;
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading gacha rates: $e");
    }
  }

  String _getImagePath(Map<String, dynamic> item) {
    final String itemName = item['name'] ?? '';
    final int categoryId = item['category_id'] ?? 0;
    
    if (categoryId == 10) {
      return 'assets/images/Fashion/Outfit/$itemName.PNG';
    } else if (categoryId == 12) {
      return 'assets/images/Fashion/HairStyle/$itemName.PNG';
    } else if (categoryId == 13) {
      return 'assets/images/Fashion/FaceStyle/$itemName.PNG';
    }
    return 'assets/images/item/EXP.png';
  }

  @override
  void dispose() {
    _rainbowController?.dispose();
    _commonItemTimer?.cancel();
    super.dispose();
  }

  void _handleRandom() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    
    // เรียก API กาชา
    final result = await ApiService.pullGacha();
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null || result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['error'] ?? 'เกิดข้อผิดพลาดในการสุ่ม'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // เปลี่ยนไปหน้าอนิเมชั่น
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, anim, secAnim) => GashaDisplayScreen(
          gachaResult: result,
        ),
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    ).then((_) {
      // Rebuild to refresh the top bar coins
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2F5FD),
      extendBody: true,
      body: Stack(
        children: [
          _buildBackground(),
          _buildMainContent(context),
          _buildTopBar(context),
          _buildBackButton(context),
          _buildBottomNav(),
        ],
      ),
    );
  }

  // ── ส่วนพื้นหลัง ──
  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        'assets/images/background/bg-head.png',
        fit: BoxFit.contain,
        alignment: Alignment.center,
        color: Colors.white.withValues(alpha: 0.5),
        colorBlendMode: BlendMode.dstIn,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }

  // ── ส่วน Main Content ──
  Widget _buildMainContent(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final topBarHeight = 75.0 + topPadding;
    // คำนวณขอบบน-ล่างให้รองรับจอเล็ก/จอใหญ่ได้ดียิ่งขึ้น
    final topOffset = size.height < 700 ? 80.0 + topPadding : 100.0 + topPadding;
    final bottomOffset = size.height < 700 ? 70.0 : 90.0;
    final hPadding = size.width < 380 ? 16.0 : 24.0;

    return Positioned(
      top: topOffset,
      left: hPadding,
      right: hPadding,
      bottom: bottomOffset,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [_buildWhiteBox(context, size), _buildHeaderTitle(size)],
          ),
        ),
      ),
    );
  }

  // ── กล่องเนื้อหาหลักสีขาว ──
  Widget _buildWhiteBox(BuildContext context, Size size) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFAAD7EA), width: 3),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.05,
            vertical: size.height > 700 ? 20 : 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: size.height > 700 ? 20 : 12),
              Image.asset(
                'assets/images/item/Gasha.png',
                width: size.width * 0.4 > 160 ? 160 : size.width * 0.4,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.card_giftcard,
                  size: 150,
                  color: Colors.pink[200],
                ),
              ),
              const SizedBox(height: 16),
              _buildRewardSection(size),
              const SizedBox(height: 16),
              const _DropRateButton(),
              const SizedBox(height: 16),
              _buildCostBox(),
              const SizedBox(height: 16),
              _RandomButton(
                isLoading: _isLoading,
                onTap: () {
                  if (_isLoading) return;
                  ConfirmGashaPopup.show(
                    context,
                    onConfirm: () {
                      Navigator.pop(context); // ปิด Popup
                      _handleRandom();        // เรียกฟังก์ชันสุ่ม
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ส่วน "รางวัลที่อาจจะได้รับ" ──
  Widget _buildRewardSection(Size size) {
    return Column(
      children: [
        Text(
          "รางวัลที่อาจจะได้รับ",
          style: TextStyle(
            fontSize: size.width * 0.05 > 20 ? 20 : size.width * 0.05,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Common (Left)
            Builder(
              builder: (context) {
                String imagePath = 'assets/images/Fashion/FaceStyle/Face_04.PNG'; // default
                double imageScale = 2.8;
                Offset imageOffset = const Offset(2, 2);
                
                if (_commonItems.isNotEmpty) {
                  final item = _commonItems[_currentCommonIndex];
                  imagePath = _getImagePath(item);
                  final int categoryId = item['category_id'] ?? 0;
                  if (categoryId == 10) {
                    // ชุด (Outfit)
                    imageScale = 2.6;
                    imageOffset = const Offset(-1, 2); // ปรับตำแหน่งแกน X, Y สำหรับชุด
                  } else if (categoryId == 12) {
                    // ทรงผม (Hair)
                    imageScale = 2.2;
                    imageOffset = const Offset(2, 2); // ปรับตำแหน่งแกน X, Y สำหรับทรงผม
                  } else if (categoryId == 13) {
                    // หน้าตา (Face)
                    imageScale = 2.8;
                    imageOffset = const Offset(2, 2); // ปรับตำแหน่งแกน X, Y สำหรับหน้าตา
                  } else {
                    imageScale = 1.5;
                    imageOffset = const Offset(2, 2);
                  }
                }

                return Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _buildRewardItem(
                        key: ValueKey<String>(imagePath),
                        imagePath: imagePath,
                        color: Colors.blue,
                        size: size,
                        imageScale: imageScale,
                        imageOffset: imageOffset,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ธรรมดา',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: size.width * 0.03 > 12 ? 12 : size.width * 0.03,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                );
              }
            ),
            const SizedBox(width: 12),
            // Epic (Middle)
            Column(
              children: [
                _buildEpicRewardItem(
                  imagePath: 'assets/images/Fashion/Outfit/Outfit_03.PNG',
                  size: size,
                  imageScale: 2.6,
                ),
                const SizedBox(height: 8),
                Text(
                  'อีปิค',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size.width * 0.03 > 12 ? 12 : size.width * 0.03,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Rare 2 (Right)
            Column(
              children: [
                _buildRewardItem(
                  imagePath: 'assets/images/Fashion/HairStyle/Hair_04.PNG',
                  color: Colors.orangeAccent,
                  size: size,
                  imageScale: 2.2,
                ),
                const SizedBox(height: 8),
                Text(
                  'แรร์',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size.width * 0.03 > 12 ? 12 : size.width * 0.03,
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── ส่วนประกอบชิ้นย่อย: Reward Item (Rare/Common) ──
  Widget _buildRewardItem({
    Key? key,
    required String imagePath,
    required Color color,
    required Size size,
    double imageScale = 2.4,
    Offset imageOffset = Offset.zero,
  }) {
    final double itemSize = size.width < 350 ? 65 : 75;
    return Container(
      key: key,
      width: itemSize,
      height: itemSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
        ),
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        child: Transform.translate(
          offset: imageOffset,
          child: Transform.scale(
            scale: imageScale,
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // ── ส่วนประกอบชิ้นย่อย: Epic Reward Item (Rainbow) ──
  Widget _buildEpicRewardItem({
    required String imagePath,
    required Size size,
    double imageScale = 1.4,
    Offset imageOffset = Offset.zero,
  }) {
    final double itemSize = size.width < 350 ? 85 : 100;
    if (_rainbowController == null) return const SizedBox();
    
    return AnimatedBuilder(
      animation: _rainbowController!,
      builder: (context, child) {
        return Container(
          width: itemSize,
          height: itemSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: SweepGradient(
              colors: const [
                Color(0xFFFFB3BA), // Pastel Red
                Color(0xFFFFDFBA), // Pastel Orange
                Color(0xFFFFFFBA), // Pastel Yellow
                Color(0xFFBAFFC9), // Pastel Green
                Color(0xFFBAE1FF), // Pastel Blue
                Color(0xFFD0BAFF), // Pastel Purple
                Color(0xFFFFB3BA), // Repeat for smooth loop
              ],
              transform: GradientRotation(_rainbowController!.value * 2 * pi),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            child: Transform.translate(
              offset: imageOffset,
              child: Transform.scale(
                scale: imageScale,
                child: Image.asset(imagePath, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── กล่องแสดงราคาสุ่ม (Tool-tip style) ──
  Widget _buildCostBox() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ใช้ 2,000',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 6),
              Image.asset(
                'assets/images/item/coin.png',
                width: 20,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.monetization_on,
                  color: Colors.blueAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -6,
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 1.5),
                  right: BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ลอยตัว (กล่องสุ่มแฟชั่น) ──
  Widget _buildHeaderTitle(Size size) {
    final fontSize = size.width * 0.055 > 24.0 ? 24.0 : size.width * 0.055;
    return FractionalTranslation(
      translation: const Offset(0, -0.5),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.08 > 40 ? 40 : size.width * 0.08,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF2374B5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "กล่องสุ่มแฟชั่น",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Top Bar ──
  Widget _buildTopBar(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withValues(alpha: 0.4),
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }

  // ── Back Button ──
  Widget _buildBackButton(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topPadding + 65.0,
      left: 16,
      child: const _BackButton(),
    );
  }

  // ── Bottom Navigation Bar ──
  Widget _buildBottomNav() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: CustomBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onNavTapped,
          onAvatarTapped: () => Navigator.pushNamed(context, '/profile'),
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton();

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final btnSize = size.width < 350 ? 40.0 : 50.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        setState(() => _isPressed = false);
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isPressed ? 0.9 : 1.0),
        child: Image.asset(
          _isPressed
              ? 'assets/images/button/bt-hover-Back.png'
              : 'assets/images/button/bt-Back.png',
          width: btnSize,
          height: btnSize,
          errorBuilder: (context, error, stackTrace) => CircleAvatar(
            backgroundColor: const Color(0xFFEEEEEE),
            radius: btnSize / 2,
            child: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          ),
        ),
      ),
    );
  }
}

class _DropRateButton extends StatefulWidget {
  const _DropRateButton();

  @override
  State<_DropRateButton> createState() => _DropRateButtonState();
}

class _DropRateButtonState extends State<_DropRateButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        setState(() => _isPressed = false);
        GashaRatePopup.show(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // เปลี่ยนสีให้เข้มขึ้นเมื่อผู้ใช้กด
          color: _isPressed ? const Color(0xFF154F7F) : const Color(0xFF2374B5),
          borderRadius: BorderRadius.circular(50),
          boxShadow: _isPressed
              ? []
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'โอกาสได้รับ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.info_outline, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _RandomButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;
  const _RandomButton({required this.onTap, this.isLoading = false});

  @override
  State<_RandomButton> createState() => _RandomButtonState();
}

class _RandomButtonState extends State<_RandomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final btnWidth = size.width * 0.5 > 150.0 ? 150.0 : size.width * 0.5;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: btnWidth,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isPressed
                ? const [Color(0xFF4B5DC1), Color(0xFF4E96D1)]
                : const [Color(0xFF556AEB), Color(0xFF59ABEC)],
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: _isPressed
              ? []
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 3),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: widget.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'สุ่ม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}