import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import '../widgets/club/club_button.dart';
import '../widgets/club/join_box.dart';

// ============================================================
// Club - หน้าหลักชมรม (สถานะ: ยังไม่มีชมรม)
// ============================================================
class Club extends StatefulWidget {
  const Club({super.key});

  @override
  State<Club> createState() => _ClubState();
}

class _ClubState extends State<Club> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────
  int _selectedIndex = 3;
  bool _showJoinBox = false;
  bool _isCreatePressed = false;
  final TextEditingController _codeController = TextEditingController();

  // ── Background Pan Animation ────────────────────────────────
  late final AnimationController _bgController;
  late final Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _bgAnim = Tween<double>(
      begin: -0.45,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ── Navigation Helper ───────────────────────────────────────
  void _onNavTapped(int index) {
    setState(() => _selectedIndex = index);
    const routes = ['/fashion', '/lobby', '/map', '/club'];
    if (index < routes.length) Navigator.pushNamed(context, routes[index]);
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 75.0 + topPadding;
    final topPad = size.height * 0.17; // ~17% จากด้านบน (responsive)
    final hPad = size.width * 0.05; // ~5% padding แนวนอน
    final btnHPad = size.width * 0.12; // ~12% padding ปุ่ม

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          // ── Background (Pan Animation) ──────────────────────
          _buildBackground(),

          // ── Top Bar ────────────────────────────────────────
          _buildTopBar(topPadding, topBarHeight),

          // ── Header + Welcome (ด้านบน) ──────────────────────
          Padding(
            padding: EdgeInsets.only(top: topPad, left: hPad, right: hPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildClubHeader(size),
                SizedBox(height: size.height * 0.025),
                _buildWelcomeText(),
              ],
            ),
          ),

          // ── Buttons (กึ่งกลางหน้าจอ) ────────────────────────
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: btnHPad),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Column ปุ่มทั้งสอง (อยู่ด้านหลัง) ─────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── ปุ่มแรก: เข้าร่วมด้วยรหัสชมรม ──────────
                      ClubButton(
                        label: 'เข้าร่วมด้วยรหัสชมรม',
                        iconPath: 'assets/images/icon/club-join.png',
                        gradientColors: _showJoinBox
                            ? const [
                                Color(0xFF1A7EC4),
                                Color(0xFF2BBFE0),
                              ] // active: เข้มขึ้น
                            : const [
                                Color(0xFF59ABEC),
                                Color(0xFF66E0FF),
                              ], // normal
                        iconBgColor: _showJoinBox
                            ? const Color(0xFF145E96) // active: เข้มขึ้น
                            : const Color(0xFF2374B5), // normal
                        shadowColor: Colors.blueAccent,
                        onTap: () {
                          setState(() => _showJoinBox = !_showJoinBox);
                        },
                      ),

                      if (_showJoinBox)
                        Padding(
                          padding: EdgeInsets.only(top: size.height * 0.01),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _showJoinBox ? 1.0 : 0.0,
                            child: JoinCodeBox(
                              codeController: _codeController,
                              onClose: () =>
                                  setState(() => _showJoinBox = false),
                            ),
                          ),
                        ),

                      if (!_showJoinBox) SizedBox(height: size.height * 0.02),

                      // ── ปุ่มที่สอง: สร้างชมรม ───────────────────
                      if (!_showJoinBox)
                        ClubButton(
                          label: 'สร้างชมรม',
                          iconPath: 'assets/images/icon/club-create.png',
                          gradientColors: _isCreatePressed
                              ? const [
                                  Color(0xFF13978D), // เข้มขึ้น
                                  Color(0xFF6BCC39), // เข้มขึ้น
                                ]
                              : const [Color(0xFF18B2A7), Color(0xFF8EFF4C)],
                          iconBgColor: _isCreatePressed
                              ? const Color(0xFF0F5C56) // เข้มขึ้น
                              : const Color(0xFF137871),
                          shadowColor: Colors.tealAccent,
                          onTapDown: () =>
                              setState(() => _isCreatePressed = true),
                          onTapUp: () =>
                              setState(() => _isCreatePressed = false),
                          onTapCancel: () =>
                              setState(() => _isCreatePressed = false),
                          onTap: () async {
                            setState(() => _isCreatePressed = false);
                            await Future.delayed(
                              const Duration(milliseconds: 150),
                            );
                            if (mounted) {
                              Navigator.pushNamed(context, '/club-create');
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Navigation Bar ────────────────────────────
          _buildBottomNav(),
        ],
      ),
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  // ── Background พร้อม Pan Animation ─────────────────────────
  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgAnim,
      builder: (_, __) => SizedBox.expand(
        child: Image.asset(
          'assets/images/background/bg7.png',
          fit: BoxFit.cover,
          alignment: Alignment(_bgAnim.value, 0.0),
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────
  Widget _buildTopBar(double topPadding, double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withValues(alpha: 0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }

  // ── กล่องหัวข้อ "ชมรม" ──────────────────────────────────────
  // ไล่สี #005395 → #2374B5 (บนลงล่าง) + design3.png ซ้าย-ขวา
  Widget _buildClubHeader(Size size) {
    final iconSize = size.width * 0.14;
    return Container(
      height: size.height * 0.085,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF005395), Color(0xFF2374B5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/design/design3.png',
              width: iconSize,
              fit: BoxFit.contain,
            ),
          ),
          Text(
            'ชมรม',
            style: TextStyle(
              fontSize: (size.width * 0.082).clamp(0.0, 32.0),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/design/design3.png',
              width: iconSize,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  // ── ข้อความยินดีต้อนรับ ─────────────────────────────────────
  // พื้นหลัง: ขาวตรงกลาง ไล่โปร่งใสซ้าย-ขวา
  Widget _buildWelcomeText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.25, 0.75, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: const Text(
        'ยินดีต้อนรับเข้าสู่ชมรม',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Bottom Navigation Bar ────────────────────────────────────
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