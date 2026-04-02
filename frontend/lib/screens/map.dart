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

    final topBarHeight = 75.0 + topPadding;

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
                  child: EnergyBar(
                    energy: 80,
                    maxEnergy: 100,
                    ticket: 1,
                    maxTicket: 5,
                  ),
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
              top: h * 0.02,
              left: w * 0.55,
              child: _buildLocation(
                imagePath: 'assets/images/map/school.PNG',
                label: 'สนามสอบ',
                width: building,
              ),
            ),

            /// หอสมุด (ซ้าย)
            Positioned(
              top: h * 0.15,
              left: w * 0.08,
              child: _buildLocation(
                imagePath: 'assets/images/map/library.PNG',
                label: 'หอสมุด',
                width: building,
              ),
            ),

            /// โรงยิม (ขวา)
            Positioned(
              top: h * 0.38,
              right: w * 0.08,
              child: _buildLocation(
                imagePath: 'assets/images/map/gym.PNG',
                label: 'โรงยิม',
                width: building,
              ),
            ),

            /// สวนสาธารณะ (กลางล่าง)
            Positioned(
              top: h * 0.48,
              left: w * 0.18,
              child: _buildLocation(
                imagePath: 'assets/images/map/park.PNG',
                label: 'สวนสาธารณะ',
                width: building * 1.1,
              ),
            ),

            /// สวนสนุก (ล่างสุด)
            Positioned(
              bottom: h * 0.10,
              left: w * 0.50,
              child: _buildLocation(
                imagePath: 'assets/images/map/theme_park.PNG',
                label: 'สวนสนุก',
                width: building * 1.2,
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
      onTap: () {
        // Navigate to LocationDetailScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationUpgradeScreen(
              user: widget.user,
              locationName: label,
              locationImage: imagePath,
              statusRewards: _locationRewards[label] ?? {},
            ),
          ),
        );
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
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          user: widget.user,
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