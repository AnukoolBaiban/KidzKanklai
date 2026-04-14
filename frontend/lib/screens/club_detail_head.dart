import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/club/club_delete_popup.dart';
import 'package:flutter_application_1/widgets/club/club_room_components.dart';

class ClubDetailHeadScreen extends StatefulWidget {
  const ClubDetailHeadScreen({super.key});

  @override
  State<ClubDetailHeadScreen> createState() => _ClubDetailHeadScreenState();
}

class _ClubDetailHeadScreenState extends State<ClubDetailHeadScreen> {
  bool _isDeletePressed = false;
  int _selectedIndex = 3;
  bool _isShowingMembers = false;

  bool _isEditingName = false;
  bool _isEditingDetail = false;

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _detailFocusNode = FocusNode();

  final TextEditingController _clubNameController = TextEditingController(
    text: 'ชื่อชมรม',
  );
  final TextEditingController _clubDetailController = TextEditingController(
    text: 'เนื้อหารายละเอียดชมรม\n\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10',
  );

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _detailFocusNode.dispose();
    _clubNameController.dispose();
    _clubDetailController.dispose();
    super.dispose();
  }

  void _showDeleteClubDialog() {
    ClubDeletePopup.show(
      context,
      onConfirm: () {
        Navigator.pop(context);
        debugPrint('Delete club confirmed');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 75.0 + topPadding;
    const headerHeight = 80.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Background ──────────────────────────────
          const ClubBackground(),

          // ── Main Content ────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + headerHeight + 16,
              left: size.width * 0.05,
              right: size.width * 0.05,
              bottom: 110,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeaderCard(),
                const SizedBox(height: 16),
                _buildTabs(),
                const SizedBox(height: 12),
                if (!_isShowingMembers) ...[
                  _buildInviteCodeSection(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildDetailsBox()),
                ] else ...[
                  Expanded(child: _buildMembersList()),
                ],
              ],
            ),
          ),

          // ── Top Bar Overlay ─────────────────────────
          ClubTopBar(topPadding: topPadding, height: topBarHeight),

          // Header ───────────
          ClubBlueHeader(
            topOffset: topBarHeight,
            title: 'ชื่อชมรม',
            onBackPressed: () => Navigator.pop(context),
          ),

          // ── Bottom Nav Bar ──────────────────────────
          ClubBottomNavBar(
            selectedIndex: _selectedIndex,
            onItemTapped: (index) => setState(() => _selectedIndex = index),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(
              'assets/images/design/design2.png',
              height: 130,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Image.asset(
              'assets/images/design/design1.png',
              width: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatarSection(),
                const SizedBox(width: 16),
                _buildLeaderInfoSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(
                    'assets/images/profile/profile_img.png',
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
          Positioned(
            bottom: -5,
            right: -5,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFE0E0E0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "3",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black,
                      height: 1,
                    ),
                  ),
                  Text(
                    "Lv.",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderInfoSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Text(
                "UsakiB",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB775),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Text(
                  "หัวหน้า",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 35,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF9DD0E7), width: 1.5),
            ),
            child: const Text(
              "แนะนำตัว",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          // ── Delete Club Button ──────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isDeletePressed = true),
              onTapCancel: () => setState(() => _isDeletePressed = false),
              onTap: () {
                setState(() => _isDeletePressed = false);
                _showDeleteClubDialog();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _isDeletePressed
                      ? const Color(0xFFC72E2E)
                      : const Color(0xFFEA4444),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ลบชมรม',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isShowingMembers = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isShowingMembers
                    ? const Color(0xFF6EB9DB)
                    : const Color(0xFF114575),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                "เกี่ยวกับชมรม",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isShowingMembers = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isShowingMembers
                    ? const Color(0xFF114575)
                    : const Color(0xFF6EB9DB),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                "สมาชิก",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCodeSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF9DD0E7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // ── Club Name TextField Row ───────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _clubNameController,
                      focusNode: _nameFocusNode,
                      readOnly: !_isEditingName,
                      onTapOutside: (event) {
                        setState(() {
                          _isEditingName = false;
                        });
                        _nameFocusNode.unfocus();
                      },
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditingName = true;
                      });
                      _nameFocusNode.requestFocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 6,
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
                      child: Image.asset(
                        'assets/images/icon/iconEdit.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.edit,
                          size: 22,
                          color: Color(0xFF4A7699),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Invite Code Row ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    "รหัสเชิญเข้าชมรม",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF00385D),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "6AF09B",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            debugPrint("Copy code tapped");
                          },
                          child: Container(
                            width: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A7699),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/icon/iconCopy.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.copy,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Scrollable Details Text ───────────────
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(right: 30),
                child: TextField(
                  controller: _clubDetailController,
                  focusNode: _detailFocusNode,
                  readOnly: !_isEditingDetail,
                  maxLines: null,
                  onTapOutside: (event) {
                    setState(() {
                      _isEditingDetail = false;
                    });
                    _detailFocusNode.unfocus();
                  },
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isEditingDetail = true;
                });
                _detailFocusNode.requestFocus();
              },
              child: Image.asset(
                'assets/images/icon/iconEdit.png',
                width: 22,
                height: 22,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.edit, size: 22, color: Color(0xFF4A7699)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 0),
        itemCount: 4,
        itemBuilder: (context, index) {
          int level = index == 0 ? 5 : (index == 1 ? 23 : 10);
          return _buildMemberCard(level);
        },
      ),
    );
  }

  Widget _buildMemberCard(int level) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F8), // Warm white
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      child: Column(
        children: [
          // Upper Row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar Column
                SizedBox(
                  width: 105,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF9DD0E7),
                              width: 2,
                            ),
                          ),
                          child: const CircleAvatar(
                            radius: 36,
                            backgroundImage: AssetImage(
                              'assets/images/profile/profile_img.png',
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Vertical Divider
                Container(width: 2, color: const Color(0xFF9DD0E7)),
                // Right Details Column
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 1. Kick button and Name on the same row!
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text(
                                "ทักษิณ ชินวัตร",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                debugPrint("Kick member");
                              },
                              style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.resolveWith<Color>(
                                      (states) =>
                                          states.contains(MaterialState.pressed)
                                          ? const Color(0xFFC72E2E)
                                          : const Color(0xFFEA4444),
                                    ),
                                foregroundColor:
                                    MaterialStateProperty.all<Color>(
                                      Colors.white,
                                    ),
                                padding:
                                    MaterialStateProperty.all<
                                      EdgeInsetsGeometry
                                    >(const EdgeInsets.all(12)),
                                minimumSize: MaterialStateProperty.all<Size>(
                                  Size.zero,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape:
                                    MaterialStateProperty.all<OutlinedBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                              ),
                              child: const Text(
                                "ไล่ออก",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 2. Role below Name
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBE7F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: const Text(
                            "สมาชิก",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // 3. Intro text below Role
                        const Text(
                          "ติดต่อได้ที่เบอร์ 123456789 เพื่อรับ 500 บาท",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Horizontal Divider
          Container(height: 2, color: const Color(0xFF9DD0E7)),
          // Lower Row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 105,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFCBE7F5),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "ภารกิจที่เสร็จแล้ว",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(width: 2, color: const Color(0xFF9DD0E7)),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildMissionCircleGridCell("1")),
                      Container(width: 2, color: const Color(0xFF9DD0E7)),
                      Expanded(child: _buildMissionCircleGridCell("2")),
                      Container(width: 2, color: const Color(0xFF9DD0E7)),
                      Expanded(child: _buildMissionCircleGridCell("3")),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCircleGridCell(String number) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF8CD853),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
