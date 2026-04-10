import 'dart:async'; // 🌟 1. เพิ่ม import นี้สำหรับการทำ Stream
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api_service.dart';

class CustomTopBar extends StatefulWidget {
  final VoidCallback? onNotificationTapped;
  final VoidCallback? onSettingsTapped;

  const CustomTopBar({
    Key? key,
    this.onNotificationTapped,
    this.onSettingsTapped,
  }) : super(key: key);

  @override
  State<CustomTopBar> createState() => _CustomTopBarState();
}

class _CustomTopBarState extends State<CustomTopBar> {
  final _supabase = Supabase.instance.client;

  // 🌟 2. เพิ่มตัวแปร Subscription สำหรับเก็บสถานะการดักฟังแบบ Real-time
  StreamSubscription<List<Map<String, dynamic>>>? _inventorySubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  int _coins = 0;
  int _tickets = 0; // QUEST_TICKET (id: 17)
  int _vouchers = 0; // EXAM_TICKET (id: 18)
  bool _hasUnreadNotifications = false;

  // ⚠️ กำหนด ID ของ Coin ในฐานข้อมูล
  final int _coinItemId = 20;

  @override
  void initState() {
    super.initState();
    _setupRealtimeInventory(); // 🌟 3. เรียกใช้ฟังก์ชันแบบ Real-time
    _triggerBackendNotificationCheck(); // กระตุ้น Backend ให้ประมวลผลเควสอัตโนมัติ
  }

  void _triggerBackendNotificationCheck() {
    // โทรไปเรียก API ทิ้งไว้เบื้องหลัง เพื่อให้ Backend อัปเดตสถานะของเควสที่หมดเวลาหรือใกล้หมดเวลา
    // และนำผลลัพธ์มาเช็คสถานะการอ่านได้เลย ทันทีแบบไม่ต้องรอ Stream ทำงาน
    ApiService.getNotifications().then((notifications) {
      if (!mounted) return;
      bool hasUnread = notifications.any((n) => !n.isRead);
      setState(() {
        _hasUnreadNotifications = hasUnread;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // 🌟 5. ฟังก์ชันใหม่ที่ใช้ .stream() ดักฟังการเปลี่ยนแปลง
  void _setupRealtimeInventory() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      _inventorySubscription = _supabase
          .from('collect')
          .stream(
            primaryKey: ['user_id', 'item_id'],
          ) // ⚠️ ต้องระบุ Primary Keys ให้ครบ
          .eq('user_id', user.id)
          .listen(
            (data) {
              if (!mounted) return;

              int tempCoins = 0;
              int tempTickets = 0;
              int tempVouchers = 0;

              for (var item in data) {
                final itemId = item['item_id'] as int;
                final qty = item['quantity'] as int? ?? 0;

                if (itemId == _coinItemId) {
                  tempCoins = qty;
                } else if (itemId == 17) {
                  tempTickets = qty;
                } else if (itemId == 18) {
                  tempVouchers = qty;
                }
              }

              setState(() {
                _coins = tempCoins;
                _tickets = tempTickets;
                _vouchers = tempVouchers;
              });
            },
            onError: (error) {
              debugPrint('Error fetching realtime inventory: $error');
            },
          );
    } catch (e) {
      debugPrint('Stream setup error: $e');
    }

    // 🌟 ดักฟังการแจ้งเตือนแบบ Real-time
    try {
      _notificationSubscription = _supabase
          .from('get_notifications')
          .stream(primaryKey: ['user_id', 'notification_id'])
          .eq('user_id', user.id)
          .listen(
            (data) {
              if (!mounted) return;

              bool hasUnread = false;
              for (var item in data) {
                final status = item['status'] as String? ?? 'unread';
                if (status == 'unread') {
                  hasUnread = true;
                  break;
                }
              }

              setState(() {
                _hasUnreadNotifications = hasUnread;
              });
            },
            onError: (error) {
              debugPrint('Error fetching realtime notifications: $error');
            },
          );
    } catch (e) {
      debugPrint('Notification stream setup error: $e');
    }
  }

  // 🌟 ฟังก์ชันช่วยจัด Format ตัวเลขให้มีลูกน้ำ (คอมมา) ถ้าเกินหลักพัน
  String _formatNumber(int number) {
    if (number >= 1000) {
      if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Row(
        children: [
          // กรอบหลักที่มี coins, tickets, vouchers
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildTopBarItem(
                      imagePath: 'assets/images/item/coin.png',
                      value: _formatNumber(_coins),
                    ),
                  ),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  Expanded(
                    child: _buildTopBarItem(
                      imagePath: 'assets/images/item/Ticket_quest_img.png',
                      value: '$_tickets/7',
                    ),
                  ),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  Expanded(
                    child: _buildTopBarItem(
                      imagePath: 'assets/images/item/Ticket_exam_img.png',
                      value: '$_vouchers/3',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Notification Button
          _buildTopBarIconButton(
            imagePath: 'assets/images/icon/icon-notification.png',
            showRedDot: _hasUnreadNotifications,
            onTap: () {
              if (widget.onNotificationTapped != null) {
                widget.onNotificationTapped!();
              } else {
                Navigator.pushNamed(context, '/notification');
              }
            },
          ),

          const SizedBox(width: 8),

          // Settings Button
          _buildTopBarIconButton(
            imagePath: 'assets/images/icon/icon-setting.png',
            onTap: () {
              if (widget.onSettingsTapped != null) {
                widget.onSettingsTapped!();
              } else {
                Navigator.pushNamed(context, '/settings');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarItem({required String imagePath, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.image_not_supported,
                size: 20,
                color: Colors.grey,
              );
            },
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required String imagePath,
    required VoidCallback onTap,
    bool showRedDot = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF59ABEC), Color(0xFF93C8D0)],
              ),
              border: Border.all(color: const Color(0xFF114575), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              imagePath,
              width: 18,
              height: 18,
              fit: BoxFit.contain,
              color: const Color(0xFF002A50),
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.settings,
                  size: 25,
                  color: Color(0xFF002A50),
                );
              },
            ),
          ),
          if (showRedDot)
            Positioned(
              top: 0,
              right: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
