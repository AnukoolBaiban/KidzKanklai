import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/energy_bar.dart';
import 'package:flutter_application_1/screens/location_upgrade.dart';

class MapScreen extends StatefulWidget {
  final User? user;

  const MapScreen({super.key, this.user});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 2;
  User? _currentUser; // 🌟 1. เพิ่มตัวแปรสำหรับเก็บข้อมูลผู้ใช้

  // 🌟 2. เพิ่มตัวแปรนี้เพื่อเอาไว้บังคับรีโหลด EnergyBar
  Key _energyKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    // ดึงข้อมูลใหม่เผื่อมีการอัปเดตก่อนหน้านี้
    if (_currentUser == null) {
      _fetchUserProfile();
    }
  }

  // 🌟 3. ฟังก์ชันดึงข้อมูลโปรไฟล์ใหม่
  Future<void> _fetchUserProfile() async {
    final updatedUser = await ApiService.getProfile(0);
    if (mounted && updatedUser != null) {
      setState(() {
        _currentUser = updatedUser;
      });
    }
  }

  // ค่าสถานะที่ได้รับจากแต่ละสถานที่
  final Map<String, Map<String, int>> _locationRewards = {
    'สนามสอบ': {
      'ความฉลาด': 5,
      'ความแข็งแรง': 0,
      'ความคิดสร้างสรรค์': 1,
    },
    'หอสมุด': {
      'ความฉลาด': 8,
      'ความแข็งแรง ': 0,
      'ความคิดสร้างสรรค์': 2,
    },
    'โรงยิม': {
      'ความฉลาด': 0,
      'ความแข็งแรง': 10,
      'ความคิดสร้างสรรค์ ': 0,
    },
    'สวนสาธารณะ': {
      'พลังงาน': 20,
    },
    'สวนสนุก': {
      'ความฉลาด': 2,
      'ความแข็งแรง': 3,
      'ความคิดสร้างสรรค์ ': 8,
    },
  };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final titleFontSize = (size.width * 0.038).clamp(14.0, 18.0);

    final topBarHeight = 60.0 + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          /// Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/bg14.png',
              fit: BoxFit.cover,
            ),
          ),

          /// Main content
          Positioned.fill(
            top: topBarHeight,
            bottom: 100 + bottomPadding,
            child: Column(
              children: [
                /// ENERGY BAR PADDING FIX
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: EnergyBar(key: _energyKey), // 🌟 2. ใส่ key เข้าไปที่นี่
                ),

                /// MAP
                Expanded(child: _buildMapContent()),
              ],
            ),
          ),

          /// Top bar
          _buildTopBar(topPadding, topBarHeight),

          /// Bottom navigation
          _buildBottomNavBar(bottomPadding),
        ],
      ),
    );
  }

  /// MAP CONTENT RESPONSIVE
  Widget _buildMapContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final building = w * 0.30;

        return Stack(
          children: [
            /// โรงเรียน (บนกลาง)
            Positioned(
              top: h * 0.01,
              left: w * 0.50,
              child: _buildLocation(
                imagePath: 'assets/images/map/school.PNG',
                label: 'สนามสอบ',
                width: building * 1.3,
              ),
            ),

            /// หอสมุด (ซ้าย)
            Positioned(
              top: h * 0.15,
              left: w * 0.08,
              child: _buildLocation(
                imagePath: 'assets/images/map/library.PNG',
                label: 'หอสมุด',
                width: building * 1.2,
              ),
            ),

            /// โรงยิม (ขวา)
            Positioned(
              top: h * 0.38,
              right: w * 0.08,
              child: _buildLocation(
                imagePath: 'assets/images/map/gym.PNG',
                label: 'โรงยิม',
                width: building * 1.2,
              ),
            ),

            /// สวนสาธารณะ (กลางล่าง)
            Positioned(
              top: h * 0.48,
              left: w * 0.13,
              child: _buildLocation(
                imagePath: 'assets/images/map/park.PNG',
                label: 'สวนสาธารณะ',
                width: building * 1.3,
              ),
            ),

            /// สวนสนุก (ล่างสุด)
            Positioned(
              bottom: h * 0.05,
              left: w * 0.50,
              child: _buildLocation(
                imagePath: 'assets/images/map/theme_park.PNG',
                label: 'สวนสนุก',
                width: building * 1.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _mapItem({
    required double left,
    required double top,
    required double width,
    required double scale,
    required String image,
    required String label,
    required double titleFontSize,
  }) {
    return Positioned(
      left: left * scale,
      top: top * scale,
      child: GestureDetector(
        onTap: () {
          print("Tapped $label");
        },
        child: Column(
          children: [
            /// IMAGE
            SizedBox(
              width: width * scale,
              child: Image.asset(image, fit: BoxFit.contain),
            ),

            SizedBox(height: 6 * scale),

            /// LABEL
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14 * scale,
                vertical: 6 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8 * scale),
                border: Border.all(
                  color: const Color(0xFFD9D9D9),
                  width: 2 * scale,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4 * scale,
                    offset: Offset(0, 2 * scale),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF313131),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// LOCATION WIDGET
  Widget _buildLocation({
    required String imagePath,
    required String label,
    required double width,
  }) {
    return _MapLocationItem(
      imagePath: imagePath,
      label: label,
      width: width,
      onTap: () async { // 🌟 1. เติม async ตรงนี้
        // 🌟 2. เติม await ให้มันหยุดรอจนกว่าผู้เล่นจะกดย้อนกลับมาจากหน้า LocationUpgradeScreen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationUpgradeScreen(
              user: _currentUser, // 🌟 ส่ง _currentUser ที่เป็น state ปัจจุบันไป

              locationName: label,
              locationImage: imagePath,
              statusRewards: _locationRewards[label] ?? {},
            ),
          ),
        );

        // 🌟 4. พอกลับมาถึงหน้านี้ สั่งเปลี่ยน Key เพื่อบังคับให้ EnergyBar รีโหลดข้อมูลใหม่ทันที
        if (mounted) {
          setState(() {
            _energyKey = UniqueKey();
          });
          // 🌟 5. รีเฟรชโปรไฟล์เพื่อให้ BottomNavigationBar อัปเดตเลเวลล่าสุด
          _fetchUserProfile();
        }
      },
    );
  }

  /// TOP BAR
  Widget _buildTopBar(double topPadding, double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }

  /// BOTTOM NAV
  Widget _buildBottomNavBar(double bottomPadding) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: CustomBottomNavigationBar(
        selectedIndex: 2,
        user: _currentUser, // 🌟 ส่ง _currentUser ไปเพื่อให้หลอด EXP อัปเดต
        onItemTapped: (index) {},
        onAvatarTapped: () =>
            Navigator.pushReplacementNamed(context, '/profile'),
        onFashionTapped: () =>
            Navigator.pushReplacementNamed(context, '/fashion'),
        onRoomTapped: () => Navigator.pushReplacementNamed(context, '/lobby'),
        onMapTapped: () {},
        onClubTapped: () => Navigator.pushReplacementNamed(context, '/club'),
      ),
    );
  }
}

class _MapLocationItem extends StatefulWidget {
  final String imagePath;
  final String label;
  final double width;
  final VoidCallback onTap;

  const _MapLocationItem({
    required this.imagePath,
    required this.label,
    required this.width,
    required this.onTap,
  });

  @override
  State<_MapLocationItem> createState() => _MapLocationItemState();
}

class _MapLocationItemState extends State<_MapLocationItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.90 : (_isHovered ? 1.05 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Column(
            children: [
              Image.asset(
                widget.imagePath,
                width: widget.width,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: _isHovered ? 8 : 4,
                      offset: Offset(0, _isHovered ? 4 : 2),
                    )
                  ],
                ),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}