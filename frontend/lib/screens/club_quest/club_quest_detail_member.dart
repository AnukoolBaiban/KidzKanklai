import 'package:flutter/material.dart';
import '../../widgets/custom_top_bar.dart';
import '../../api_service.dart';
import '../../screens/lobby.dart';
import '../../widgets/confirm_giveup_popup.dart';
import '../../widgets/reward_popup.dart';
import 'club_quest_quiz_member.dart';

class ClubQuestDetailScreen extends StatefulWidget {
  final User? user;

  const ClubQuestDetailScreen({Key? key, this.user}) : super(key: key);

  @override
  State<ClubQuestDetailScreen> createState() => _ClubQuestDetailScreenState();
}

class _ClubQuestDetailScreenState extends State<ClubQuestDetailScreen> {
  bool _isPressed = false;

  // Mock Data
  final String mockTitle = "สรุปคณิตบทที่ 11111111111111111";
  final String mockDescription =
      "อ่านวันละ 2 บท และทำการบ้านบทที่ 1 หน้า 75";
  final String mockStartDate = "25/06/68";
  final String mockEndDate = "27/06/68";
  final String? mockImagePath = "assets/images/achievement/achievement1.png";

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topBarHeight = 75.0 + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          _buildBackground(),

          // Top Bar
          _buildTopBar(topPadding, topBarHeight),

          // Main Content
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + 10,
              left: size.width * 0.05,
              right: size.width * 0.05,
              bottom: bottomPadding + 100, // เว้นที่ให้ปุ่ม
            ),
            child: Column(
              children: [
                // Back Button
                Row(children: [_buildBackButton()]),

                SizedBox(height: 10),

                // Content Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(0xFFAAD7EA), width: 3),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Scrollable Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Quest Title and Dates
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        mockTitle,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF447199),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'สร้าง $mockStartDate',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          'วันที่สิ้นสุด $mockEndDate',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),

                                Container(height: 2, color: Color(0xFFB3E5FC)),

                                SizedBox(height: 20),

                                // รูปภาพ Section
                                if (mockImagePath != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: Color(0xFF9DD0E7),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),

                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title อยู่ในกล่อง
                                        Text(
                                          'รูปภาพ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF002A50),
                                          ),
                                        ),

                                        SizedBox(height: 12),

                                        // Responsive Image
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Center(
                                              child: Container(
                                                width:
                                                    constraints.maxWidth *
                                                    0.6, // responsive
                                                constraints: BoxConstraints(
                                                  maxWidth: 300,
                                                  maxHeight: 300,
                                                ),
                                                child: AspectRatio(
                                                  aspectRatio:
                                                      1, // ทำให้รูปเป็นสี่เหลี่ยม
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: Image.asset(
                                                      mockImagePath!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Container(
                                                              color: Color(
                                                                0xFFE8F4F8,
                                                              ),
                                                              child: Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .broken_image,
                                                                  size: 60,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 20),
                                ],

                                // Description
                                Text(
                                  mockDescription,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF313131),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Header "รายละเอียด"
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildHeaderTitle(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Buttons
          _buildBottomButtons(bottomPadding),
        ],
      ),
    );
  }

  // ==================== Components ====================

  Widget _buildBackground() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        color: const Color(0xFFE2F5FD),
        alignment: Alignment.center,
        child: Image.asset(
          "assets/images/background/bg-head.png",
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width * 0.8,
          errorBuilder: (context, error, stackTrace) {
            return Container();
          },
        ),
      ),
    );
  }

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
          // user: widget.user,
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LobbyScreen(user: widget.user)),
          ).then((_) => setState(() => _isPressed = false));
        }
      },
      child: Image.asset(
        _isPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: Color(0xFF2374B5)),
          );
        },
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2374B5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            "รายละเอียด",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons(double bottomPadding) {
    return Positioned(
      bottom: bottomPadding + 40,
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: Row(
        children: [
          Expanded(
            child: _buildButton(
              text: 'ตอบคำถาม',
              color: Color(0xFF4A8FE7),
              useGradient: true,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClubQuestQuizMemberScreen(user: widget.user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    bool useGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: useGradient ? null : color,
        gradient: useGradient
            ? LinearGradient(
                colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

