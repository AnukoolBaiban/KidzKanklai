import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/reward_popup.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/confirm_delete_popup.dart';
import 'package:flutter_application_1/screens/all_quest.dart';


class NotificationDetailScreen extends StatefulWidget {
  final NotificationModel notification;
  final User? user;

  const NotificationDetailScreen({
    Key? key,
    required this.notification,
    this.user,
  }) : super(key: key);

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  Key _topBarKey = UniqueKey();
  bool _isPressed = false;
  bool _isDeleting = false;
  
  // 🌟 เพิ่มตัวแปรเช็คสถานะการรับของ
  bool _isClaiming = false;
  bool _isClaimed = false; 

  // 🌟 เพิ่มตัวแปรจัดการของรางวัล
  bool _isLoadingRewards = true;
  List<Map<String, dynamic>> _rewardsList = [];

  @override
  void initState() {
    super.initState();
    if (!widget.notification.isRead) {
      ApiService.markNotificationRead(widget.notification.id);
    }
    
    // 🌟 ถ้าเป็นจดหมายของรางวัล ให้โหลดข้อมูลจาก API ก่อน
    if (widget.notification.type == 'reward') {
      _fetchRewardDetails();
    } else {
      _isLoadingRewards = false;
    }
  }

  // 🌟 ฟังก์ชันโหลดของรางวัลและสถานะว่ารับไปหรือยัง
  Future<void> _fetchRewardDetails() async {
    final result = await ApiService.getNotificationRewards(widget.notification.id);
    if (mounted && result != null) {
      setState(() {
        _isClaimed = result['is_claimed'] ?? false;
        _rewardsList = List<Map<String, dynamic>>.from(result['rewards'] ?? []);
        _isLoadingRewards = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingRewards = false);
    }
  }

  Future<void> _deleteAndGoBack() async {
    setState(() => _isDeleting = true);
    final ok = await ApiService.deleteNotification(widget.notification.id);
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (ok) {
      Navigator.pop(context, true); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง')),
      );
    }
  }

  // 🌟 ฟังก์ชันกดรับรางวัล
  Future<void> _claimReward() async {
    setState(() => _isClaiming = true);

    // 1. ดึง Profile ก่อนรับรางวัลเพื่อเช็ค Level Up
    final profileBefore = await ApiService.getProfile(0);
    final oldLevel = profileBefore?.level ?? 0;

    // 2. ยิง API รับของ
    final result = await ApiService.claimNotificationReward(widget.notification.id);
    
    if (!mounted) return;
    setState(() => _isClaiming = false);

    // 3. จัดการผลลัพธ์
    if (result != null && result['success'] == true) {
      setState(() => _isClaimed = true); // เปลี่ยนปุ่มเป็น "รับแล้ว"
      
      // ดึง Profile หลังรับเพื่อโชว์ Level Up
      final profileAfter = await ApiService.getProfile(0);
      final newLevel = profileAfter?.level ?? oldLevel;
      final didLevelUp = newLevel > oldLevel;

      final apiRewards = (result['rewards'] as List?) ?? [];
      
      List<RewardData> popupRewards = apiRewards.map<RewardData>((rw) {
        return RewardData(
          type: rw['name'] == 'EXP' ? 'EXP' : 'ITEM',
          amount: rw['amount'] ?? 0,
          itemName: rw['name'],
          itemImage: rw['image'],
        );
      }).toList();

      // โชว์ Popup อลังการ
      await RewardPopup.show(
        context,
        rewards: popupRewards,
        leveledUp: didLevelUp,
        baseLevel: oldLevel,
        newLevel: newLevel,
        user: profileAfter ?? widget.user,
      );

    } else {
      // ❌ กรณี Error หรือรับไปแล้ว
      final errorMsg = result?['error'] ?? 'เกิดข้อผิดพลาด';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
      
      // ถ้า Backend ฟ้องว่ารับไปแล้ว ให้บล็อกปุ่มทิ้งเลย
      if (errorMsg == 'คุณรับของรางวัลนี้ไปแล้ว') {
        setState(() => _isClaimed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    final isAchievement = notif.type == 'achievement';
    final isFail = notif.type.startsWith('quest_fail');
    final isReward = notif.type == 'reward'; // 🌟 เช็คว่าเป็นจดหมายแจกของไหม

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/bg1.png',
              fit: BoxFit.cover,
            ),
          ),

          Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 10),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.82),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFAAD7EA),
                                    width: 3,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 40),

                                    // Icon
                                    SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: notif.iconPath.startsWith('http')
                                            ? Image.network(
                                                notif.iconPath,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => Icon(
                                                  isAchievement ? Icons.emoji_events : isReward ? Icons.card_giftcard : Icons.notifications,
                                                  size: 48,
                                                  color: isAchievement ? const Color(0xFFFFA000) : isReward ? Colors.green : const Color(0xFF2374B5),
                                                ),
                                              )
                                            : Image.asset(
                                                notif.iconPath,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => Icon(
                                                  isAchievement ? Icons.emoji_events : isReward ? Icons.card_giftcard : Icons.notifications,
                                                  size: 48,
                                                  color: isAchievement ? const Color(0xFFFFA000) : isReward ? Colors.green : const Color(0xFF2374B5),
                                                ),
                                              ),
                                      ),
                                    ),

                                    if (isAchievement) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFFFFCA28), borderRadius: BorderRadius.circular(12)),
                                        child: const Text('ความสำเร็จ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],

                                    if (isReward) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFF4CB050), borderRadius: BorderRadius.circular(12)),
                                        child: const Text('ของรางวัล', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],

                                    if (isFail) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(12)),
                                        child: const Text('ภารกิจล้มเหลว', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],

                                    const SizedBox(height: 16),

                                    // Title
                                    Text(
                                      notif.title.isNotEmpty ? notif.title : 'แจ้งเตือน',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                      textAlign: TextAlign.center,
                                    ),

                                    const SizedBox(height: 16),

                                    // Description
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Text(
                                          notif.detail.isNotEmpty ? notif.detail : '-',
                                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    // 🌟 แทรกส่วนนี้: โชว์กล่องของรางวัลที่จะได้รับ
                                    if (isReward) ...[
                                      const SizedBox(height: 24),
                                      const Text(
                                        'ของรางวัลที่จะได้รับ:',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF002A50)),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      _isLoadingRewards
                                        ? const CircularProgressIndicator() // โชว์โหลด
                                        : _rewardsList.isEmpty
                                            ? const Text('ไม่พบข้อมูลของรางวัล', style: TextStyle(fontSize: 12, color: Colors.grey))
                                            : Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                alignment: WrapAlignment.center,
                                                children: _rewardsList.map((r) => _buildRewardBadge(r)).toList(),
                                              ),
                                    ],

                                    const SizedBox(height: 12),

                                    Text(
                                      notif.relativeTime,
                                      style: const TextStyle(fontSize: 11, color: Colors.black38),
                                      textAlign: TextAlign.center,
                                    ),

                                    if (notif.readAtText != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        notif.readAtText!,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF2374B5)),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],

                                    const SizedBox(height: 4),

                                    Text(
                                      notif.autoDeletionText,
                                      style: const TextStyle(fontSize: 11, color: Color.fromARGB(95, 214, 0, 0)),
                                      textAlign: TextAlign.center,
                                    ),

                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),

                            _buildHeaderTitle(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 🌟 ส่วนปุ่มด้านล่าง (เปลี่ยนฟังก์ชันไปใช้ _buildActionButtons)
                      _buildActionButtons(isReward),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🌟 ฟังก์ชันรวมปุ่มด้านล่าง
  Widget _buildActionButtons(bool isReward) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ปุ่มลบ
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isDeleting
                ? null
                : () {
                    ConfirmDeletePopup.show(
                      context,
                      title: 'ยืนยันที่จะลบการแจ้งเตือนนี้หรือไม่?',
                      onConfirm: () {
                        Navigator.pop(context);
                        _deleteAndGoBack(); 
                      },
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA4444),
              disabledBackgroundColor: const Color(0xFFEA4444).withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: _isDeleting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('ลบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),

        // 🌟 ถ้าเป็นจดหมายรางวัล ให้โชว์ปุ่มรับของเพิ่มเข้ามา
        if (isReward) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              // ปิดปุ่มถ้ารับไปแล้ว หรือกำลังโหลด
              onPressed: (_isClaimed || _isClaiming) ? null : _claimReward,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isClaimed ? Colors.grey : const Color(0xFF4CB050),
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: _isClaiming
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isClaimed ? 'รับรางวัลแล้ว' : 'รับรางวัล',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeleteButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(flex: 1, child: const SizedBox()),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isDeleting
                ? null
                : () {
                    ConfirmDeletePopup.show(
                      context,
                      title: 'ยืนยันที่จะลบการแจ้งเตือนนี้หรือไม่?',
                      onConfirm: () {
                        Navigator.pop(context); // ปิด popup ก่อน
                        _deleteAndGoBack(); // ค่อยลบจริง
                      },
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA4444),
              disabledBackgroundColor: const Color(0xFFEA4444).withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'ลบ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        Expanded(flex: 1, child: const SizedBox()),
      ],
    );
  }

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            color: Colors.black.withOpacity(0.4),
            child: CustomTopBar(
              key: _topBarKey,
              onNotificationTapped: () {
                Navigator.pop(context, true); // กลับไปหน้า Notification เดิม
              },
              onSettingsTapped: () {
                Navigator.pushReplacementNamed(context, '/setting');
              },
            ),
          ),
          _buildBackButton(),
      ],
    );
  }

  Widget _buildBackButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final buttonSize = screenWidth * 0.12;
    final topPadding = screenHeight * 0.010;

    return Padding(
      padding: EdgeInsets.only(left: screenWidth * 0.05, top: topPadding),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () async {
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;
          setState(() => _isPressed = false);
          Navigator.pop(context, true);
        },
        child: Image.asset(
          _isPressed
              ? 'assets/images/button/bt-hover-Back.png'
              : 'assets/images/button/bt-Back.png',
          width: buttonSize,
          height: buttonSize,
        ),
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2374B5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            "แจ้งเตือน",
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

  // 🌟 ฟังก์ชันสร้างป้ายของรางวัล (ใช้ RewardBadge เหมือนหน้าภารกิจ)
  Widget _buildRewardBadge(Map<String, dynamic> r) {
    final String name = r['name'] ?? 'Item';
    final int qty = r['amount'] ?? 1;
    final String image = r['image'] ?? 'assets/images/item/Gasha.png';
    
    final bool isExp = name.toUpperCase().contains('EXP');
    
    // 1. กำหนดสีเริ่มต้น
    Color badgeColor = isExp ? const Color(0xFFC8E6C9) : const Color(0xFFFFE0B2);
    
    // 2. ถ้ากดรับไปแล้ว ให้ของรางวัลกลายเป็นสีเทา
    if (_isClaimed) {
      badgeColor = Colors.grey.shade300;
    }
    
    // 3. กำหนดข้อความจำนวน
    final String valueText = isExp ? '+$qty' : 'x$qty';

    // 🌟 4. เรียกใช้ RewardBadge
    return RewardBadge(
      label: name,
      value: valueText,
      color: badgeColor,
      iconPath: image,
      isClaimed: _isClaimed, // ส่งสถานะไปเผื่อตัว Widget มีการจัดการสีเทาซ้อนไว้อีกชั้น
    );
  }
}
