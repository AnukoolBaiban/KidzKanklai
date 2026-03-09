import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/lobby.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/screens/quest_detail.dart';
import 'package:flutter_application_1/widgets/annotation.dart';
import 'package:flutter_application_1/widgets/tutorial_quest.dart';
import 'package:google_fonts/google_fonts.dart';

class AllQuestScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final User? user;

  const AllQuestScreen({super.key, this.initialData, this.user});

  @override
  State<AllQuestScreen> createState() => _AllQuestScreenState();
}

class _AllQuestScreenState extends State<AllQuestScreen> {
  // --- ตัวแปร State ---
  bool _isPressed = false; // สถานะการกดปุ่ม Back
  int _selectedTabIndex = 0; // Tab ที่เลือกปัจจุบัน
  final List<String> _tabs = [
    "ทั้งหมด",
    "ระบบ",
    "ส่วนตัว",
    "ประวัติ",
  ]; // รายชื่อ Tab

  // --- ข้อมูลจำลอง (Mock Data) ---
  final List<Map<String, dynamic>> _allQuests = [
    {
      "title": "สรุปฟิสิกส์บทที่ 5",
      "type": "ทั่วไป",
      "category": "ส่วนตัว",
      "exp": 100,
      "item": "assets/images/item/Gasha.png",
      "itemAmount": 1,
      "daysLeft": 1,
      "isSystem": false,
    },
    {
      "title": "สรุปคณิตบทที่ 1",
      "type": "ทั่วไป",
      "category": "ส่วนตัว",
      "exp": 100,
      "item": "assets/images/item/Ticket_exam_img.png",
      "itemAmount": 1,
      "daysLeft": 5,
      "isSystem": false,
    },
    {
      "title": "สำเร็จภารกิจระบบ 6 อย่าง",
      "type": "ระบบ",
      "category": "ระบบ",
      "exp": 100,
      "item": "assets/images/item/Ticket_exam_img.png",
      "itemAmount": 1,
      "daysLeft": 1,
      "isSystem": true,
      "progress": 0,
      "totalReq": 6,
      "isClaimed": false,
    },
    {
      "title": "เข้าร่วมการสอบ 3 ครั้ง",
      "type": "ระบบ",
      "category": "ระบบ",
      "exp": 100,
      "item": "assets/images/item/Ticket_exam_img.png",
      "itemAmount": 1,
      "daysLeft": 1,
      "isSystem": true,
      "progress": 3,
      "totalReq": 3,
      "isClaimed": false,
    },
  ];

  // --- Widget: Tutorial Quest Popup ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => const TutorialQuestPopup(),
      );
    });
  }

  // --- Main Screen ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final topBarHeight = 75.0 + topPadding;
    final headerHeight = 80.0;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),

          // Main Content
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + headerHeight + 10, // เว้นที่ให้ Header ด้านบน
              bottom: 110 + bottomPadding, // เว้นที่ให้ Bottom Bar ด้านล่าง
              left: size.width * 0.05,
              right: size.width * 0.05,
            ),
            child: Column(
              children: [
                _buildTabs(), // ส่วน Tab และปุ่มสร้าง Quest
                const SizedBox(height: 4),
                Expanded(child: _buildQuestContent()), // รายการ Quest
              ],
            ),
          ),

          // Top Bar
          _buildTopBar(topPadding, topBarHeight),

          // Header & Title
          _buildBlueHeader(topBarHeight),

          // Bottom Navigation
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  // --- Widget: พื้นหลัง (Background Layer) ---
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
        ),
      ),
    );
  }

  // --- Widget: แถบข้อมูลผู้ใช้ (Top Bar Overlay) ---
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

  // Header with Back Button & Title
  Widget _buildBlueHeader(double topOffset) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF015496), Color(0xFF2273B4)],
          ),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: _buildBackButton(),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Image.asset(
                          'assets/images/design/design3.png',
                          width: 75,
                          height: 75,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "ภารกิจ",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
              ],
            ),
            const Positioned(bottom: 8, right: 15, child: AnnotationButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 200));
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
      ),
    );
  }

  // Bottom Navigation
  Widget _buildBottomNavBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: CustomBottomNavigationBar(
        selectedIndex: -1,
        playerLevel: widget.user?.level ?? 1,
        avatarUrl: null,
        onItemTapped: (index) {},
        onAvatarTapped: () =>
            Navigator.pushReplacementNamed(context, '/profile'),
        onFashionTapped: () =>
            Navigator.pushReplacementNamed(context, '/fashion'),
        onRoomTapped: () => Navigator.pushReplacementNamed(context, '/lobby'),
        onMapTapped: () => Navigator.pushReplacementNamed(context, '/map'),
        onClubTapped: () => Navigator.pushReplacementNamed(context, '/club'),
      ),
    );
  }

  // ส่วน Tab และปุ่มสร้าง Quest
  Widget _buildTabs() {
    return Row(
      children: [
        for (int i = 0; i < _tabs.length; i++)
          Expanded(child: _buildTabItem(i)),
        const SizedBox(width: 8),
        // ปุ่มสร้าง Quest
        Builder(
          builder: (ctx) =>
              _CreateQuestButton(onTap: () => _showCreateQuestPopup(ctx)),
        ),
      ],
    );
  }

  Widget _buildTabItem(int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF002A50) : const Color(0xFF2374B5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _tabs[index],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateQuestPopup(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      useSafeArea: false, // เพื่อให้พิกัด absolute ตรงกันทุกขนาดจอ
      builder: (BuildContext dialogContext) {
        return Stack(
          children: [
            // Replica button to prevent the barrier from darkening it
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: _CreateQuestButton(
                onTap: () => Navigator.pop(dialogContext),
              ),
            ),
            Positioned(
              top:
                  offset.dy +
                  renderBox.size.height +
                  15, // ระยะห่างลงมาจากปุ่มมากขึ้นเพื่อไม่ให้บัง
              right:
                  MediaQuery.of(context).size.width *
                  0.05, // จัดขวาให้ตรงกับขอบ padding หน้าจอเหมือนปุ่ม
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.45,
                  constraints: const BoxConstraints(
                    minWidth: 150,
                    maxWidth: 200,
                  ),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPopupButton("ภารกิจทั่วไป", () {
                        Navigator.pop(dialogContext);
                        Navigator.pushNamed(context, '/createnormalquest');
                      }),
                      const SizedBox(height: 6),
                      _buildPopupButton("ภารกิจทันที", () {
                        Navigator.pop(dialogContext);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopupButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown, // บีบอักษรให้พอดีกล่องถ้าจอแคบ
          child: Text(
            text,
            style: GoogleFonts.kanit(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget: รายการ Quest (List View Logic) ---
  Widget _buildQuestContent() {
    List<Map<String, dynamic>> filteredQuests = [];

    // กรองข้อมูลตาม Tab ที่เลือก
    if (_selectedTabIndex == 0) {
      filteredQuests = _allQuests;
    } else {
      String category = _tabs[_selectedTabIndex];
      filteredQuests = _allQuests
          .where((q) => q['category'] == category)
          .toList();
    }

    // เรียงลำดับ: Quest ที่ยังไม่รับรางวัลขึ้นก่อน
    filteredQuests.sort((a, b) {
      bool aClaimed = a['isClaimed'] ?? false;
      bool bClaimed = b['isClaimed'] ?? false;
      if (aClaimed && !bClaimed) return 1;
      if (!aClaimed && bClaimed) return -1;
      return 0;
    });

    if (filteredQuests.isEmpty) {
      return Center(
        child: Text(
          "ไม่มีรายการภารกิจในขณะนี้",
          style: GoogleFonts.kanit(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: filteredQuests.length,
      itemBuilder: (context, index) {
        return QuestCard(
          quest: filteredQuests[index],
          onClaim: () {
            setState(() {
              filteredQuests[index]['isClaimed'] = true;
            });
          },
          onViewDetails: () {
            // เชื่อมไปหน้าดูรายละเอียด
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuestDetailScreen(
                  quest: QuestItem(
                    id: index.toString(),
                    name: filteredQuests[index]['title'],
                    description: "รายละเอียดภารกิจ...",
                    imagePath: null,
                    startDate: DateTime.now(),
                    dueDate: DateTime.now().add(
                      Duration(days: filteredQuests[index]['daysLeft'] ?? 1),
                    ),
                    isCompleted: filteredQuests[index]['isClaimed'] ?? false,
                  ),
                  user: widget.user,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CreateQuestButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateQuestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF68E2FA), Color(0xFF2374B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Center(
            child: Image.asset(
              "assets/images/button/bt-create.png",
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class QuestCard extends StatelessWidget {
  final Map<String, dynamic> quest;
  final VoidCallback onClaim;
  final VoidCallback onViewDetails;

  const QuestCard({
    super.key,
    required this.quest,
    required this.onClaim,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    bool isSystem = quest['category'] == 'ระบบ';
    bool isClaimed = quest['isClaimed'] ?? false;
    int progress = quest['progress'] ?? 0;
    int totalReq = quest['totalReq'] ?? 1;
    bool isComplete = progress >= totalReq;

    // Badge Colors
    List<Color> badgeColors = isSystem
        ? [const Color(0xFF6CC732), const Color(0xFFCEFFB2)] // System: Green
        : [const Color(0xFF59ABEC), const Color(0xFFC6F4FF)]; // General: Blue

    // Background Logic
    Decoration backgroundDecoration = BoxDecoration(
      color: isClaimed
          ? Colors.grey.shade300.withOpacity(0.85)
          : Colors.white.withOpacity(0.8),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: isClaimed ? Colors.grey : const Color(0xFF9DD0E7),
        width: 2,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: backgroundDecoration,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Content (Type, Rewards)
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Badge & Title Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, // slightly reduced padding
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: badgeColors,
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isSystem ? 'ระบบ' : quest['type'],
                              style: const TextStyle(
                                fontSize: 13, // slightly smaller font
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Title
                        Expanded(
                          child: Text(
                            quest['title'],
                            style: const TextStyle(
                              fontSize: 15, // slightly smaller font
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Rewards
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        RewardBadge(
                          label: "EXP",
                          value: "+${quest['exp']}",
                          color: Colors.green.shade100,
                          iconPath: 'assets/images/item/EXP.png',
                          isClaimed: isClaimed,
                        ),
                        RewardBadge(
                          label: "Item",
                          value: "x${quest['itemAmount']}",
                          color: Colors.orange.shade100,
                          iconPath: quest['item'],
                          isClaimed: isClaimed,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Vertical Divider
            Container(
              width: 1,
              color: isClaimed ? Colors.grey : const Color(0xFF9DD0E7),
            ),

            // Right Content (Button, Status)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Action Button
                    if (isClaimed)
                      _buildActionButton(text: 'สำเร็จ', onPressed: null)
                    else if (isSystem && isComplete)
                      _buildActionButton(
                        text: 'รับรางวัล',
                        onPressed: onClaim,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF85D755), Color(0xFF34C759)],
                        ),
                      )
                    else
                      _buildActionButton(
                        text: isSystem ? 'รับรางวัล' : 'รายละเอียด',
                        onPressed: isSystem ? null : onViewDetails,
                        bgColor: isSystem
                            ? Colors.grey
                            : const Color(0xFF536DFE),
                      ),

                    const SizedBox(height: 12),

                    // Progress or Days Left
                    if (isSystem) ...[
                      _buildProgressBar(
                        isClaimed || isComplete,
                        progress,
                        totalReq,
                      ),
                      const SizedBox(height: 4),
                    ],

                    Text(
                      "เหลืออีก ${quest['daysLeft']} วัน",
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    Color? bgColor,
    Gradient? gradient,
  }) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: gradient == null
          ? (bgColor ?? Colors.grey)
          : Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.grey,
      disabledForegroundColor: Colors.white,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      minimumSize: const Size(double.infinity, 36),
      elevation: 0,
    );
    Widget btn = ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
    if (gradient != null)
      btn = Container(
        width: double.infinity,
        height: 36,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: btn,
      );
    return btn;
  }

  Widget _buildProgressBar(bool isDone, int progress, int totalReq) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: isDone ? null : Colors.grey.shade300,
        gradient: isDone
            ? const LinearGradient(
                colors: [Color(0xFF59ABEC), Color(0xFF85D755)],
              )
            : null,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        isDone ? "$totalReq/$totalReq" : "$progress/$totalReq",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDone ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

class RewardBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? iconPath;
  final bool isClaimed;

  const RewardBadge({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.iconPath,
    this.isClaimed = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Center(
                child: iconPath != null
                    ? Image.asset(iconPath!, width: 36, height: 36)
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF81D4FA), Color(0xFF81C784)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "EXP",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black26,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );

    if (isClaimed) {
      badge = Stack(
        alignment: Alignment.center,
        children: [
          badge,
          Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      );
    }

    return badge;
  }
}
