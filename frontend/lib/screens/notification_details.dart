import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';

import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/confirm_delete_popup.dart';

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

  @override
  void initState() {
    super.initState();
    // Mark as read เมื่อเปิดหน้า Detail
    if (!widget.notification.isRead) {
      ApiService.markNotificationRead(widget.notification.id);
    }
  }

  Future<void> _deleteAndGoBack() async {
    setState(() => _isDeleting = true);

    final ok = await ApiService.deleteNotification(widget.notification.id);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (ok) {
      Navigator.pop(context, true); // กลับไปหน้า Notification list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    final isAchievement = notif.type == 'achievement';
    final isFail = notif.type.startsWith('quest_fail');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/bg1.png',
              fit: BoxFit.cover,
            ),
          ),

          // Main Content
          Positioned(
            top: 150,
            left: 24,
            right: 24,
            bottom: 24,
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
                                            isAchievement
                                                ? Icons.emoji_events
                                                : Icons.notifications,
                                            size: 48,
                                            color: isAchievement
                                                ? const Color(0xFFFFA000)
                                                : const Color(0xFF2374B5),
                                          ),
                                        )
                                      : Image.asset(
                                          notif.iconPath,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Icon(
                                            isAchievement
                                                ? Icons.emoji_events
                                                : Icons.notifications,
                                            size: 48,
                                            color: isAchievement
                                                ? const Color(0xFFFFA000)
                                                : const Color(0xFF2374B5),
                                          ),
                                        ),
                                ),
                              ),

                              if (isAchievement) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFCA28),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '🏆 ความสำเร็จ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],

                              if (isFail) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '❌ ภารกิจล้มเหลว',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Title
                              Text(
                                notif.title.isNotEmpty
                                    ? notif.title
                                    : 'แจ้งเตือน',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 16),

                              // Description
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    notif.detail.isNotEmpty
                                        ? notif.detail
                                        : '-',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height: 1.6,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // วันที่ได้รับ
                              Text(
                                notif.relativeTime,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black38,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              // วันที่อ่านแล้ว (แสดงเฉพาะเมื่ออ่านแล้ว)
                              if (notif.readAtText != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  notif.readAtText!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2374B5),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],

                              const SizedBox(height: 4),

                              // วันที่จะถูกลบอัตโนมัติ
                              Text(
                                notif.autoDeletionText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color.fromARGB(95, 214, 0, 0),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 8),


                            ],
                          ),
                        ),
                      ),

                      // Header Title
                      _buildHeaderTitle(),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ปุ่มลบ (ล่างสุด)
                _buildDeleteButton(),
              ],
            ),
          ),

          _buildTopBar(),
        ],
      ),
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: screenHeight * 0.098,
            color: Colors.black.withOpacity(0.4),
            alignment: Alignment.bottomCenter,
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
      ),
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
}
