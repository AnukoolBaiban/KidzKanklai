import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';

import 'package:flutter_application_1/screens/lobby.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/screens/notification_details.dart';

class NotificationScreen extends StatefulWidget {
  final User? user;

  const NotificationScreen({super.key, this.user});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> notifications = [];
  bool _isPressed = false;
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      notifications = [
        NotificationItem(
          id: '1',
          imagePath: 'assets/images/icon/trophy.png',
          title: 'เควส Normal ใกล้หมดเวลา!',
          description:
              'ภารกิจ "สรุปคณิตบทที่ 1" ของคุณจะหมดเวลาในอีก 1 ชั่วโมง',
          timestamp: '5 นาทีที่แล้ว',
          isRead: false,
        ),
        NotificationItem(
          id: '2',
          imagePath: 'assets/images/icon/iconAchievement.png',
          title: 'ปลดล็อกความสำเร็จใหม่',
          description:
              'ยินดีด้วย! คุณปลดล็อก "นักวางแผนมือใหม่" แล้ว อย่าลืมเข้าไปรับ...',
          timestamp: '5 ชั่วโมงที่แล้ว',
          isRead: true,
        ),
        NotificationItem(
          id: '3',
          imagePath: 'assets/images/icon/communication.png',
          title: 'ภารกิจใหม่จากชมรม',
          description:
              'หัวหน้าชมรมได้สร้าง "เควสติวหนังสือ" เข้าไปทำเพื่อรับ 200...',
          timestamp: '7 ชั่วโมงที่แล้ว',
          isRead: true,
        ),
        NotificationItem(
          id: '4',
          imagePath: 'assets/images/icon/education.png',
          title: 'คุณพร้อมสอบแล้ว!',
          description:
              'ค่าความสามารถของคุณถึงเกณฑ์แล้ว คุณสามารถใช้สิทธิเข้า...',
          timestamp: '5 ชั่วโมงที่แล้ว',
          isRead: true,
        ),
      ];
    });
  }

  void _deleteAllNotifications() {
    setState(() {
      notifications.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ลบการแจ้งเตือนทั้งหมดแล้ว')));
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _deleteSelectedNotifications() {
    setState(() {
      notifications.removeWhere((item) => _selectedIds.contains(item.id));
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ลบการแจ้งเตือนที่เลือกแล้ว')));
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/background/bg1.png', fit: BoxFit.cover),
          ),

          _buildTopBar(),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 150, 24, 24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 680,
                  padding: EdgeInsets.all(20),
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
                      const SizedBox(height: 30),

                      // Progress
                      Text(
                        'จำนวน ${notifications.length}/100',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // ListView
                      Expanded(
                        child: notifications.isEmpty
                            ? Center(
                                child: Text(
                                  'ไม่มีการแจ้งเตือน',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: notifications.length,
                                itemBuilder: (context, index) {
                                  return _buildNotificationCard(
                                    context,
                                    notifications[index],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                _buildHeaderTitle(),

                Positioned(
                  bottom: 0,
                  left: 20,
                  right: 20,
                  child: _buildBottomButtons(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildTopBar() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            child: CustomTopBar(
              user: widget.user,
              onNotificationTapped: () {
                Navigator.pushNamed(context, '/notification');
              },
              onSettingsTapped: () {
                Navigator.pushNamed(context, '/setting');
              },
            ),
          ),

          // Back Button
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 10),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) {},
              onTapCancel: () => setState(() => _isPressed = false),
              onTap: () async {
                await Future.delayed(const Duration(milliseconds: 200));
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LobbyScreen()),
                ).then((_) {
                  setState(() => _isPressed = false);
                });
              },
              child: Image.asset(
                _isPressed
                    ? 'assets/images/button/bt-hover-Back.png'
                    : 'assets/images/button/bt-Back.png',
                width: 50,
                height: 50,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_isSelectionMode) {
      // โหมดเลือก: แสดงปุ่ม "ยกเลิก" และ "ลบ"
      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                onPressed: notifications.isEmpty ? null : _toggleSelectionMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'ยกเลิก',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _selectedIds.isEmpty
                  ? null
                  : _deleteSelectedNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEA4444),
                disabledBackgroundColor: Color(0xFFEA4444).withOpacity(0.5),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'ลบ (${_selectedIds.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // โหมดปกติ: แสดงปุ่ม "ลบทั้งหมด" และ "เลือก"
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: notifications.isEmpty ? null : _deleteAllNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEA4444),
                disabledBackgroundColor: Color(0xFFEA4444).withOpacity(0.5),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'ลบทั้งหมด',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                onPressed: notifications.isEmpty ? null : _toggleSelectionMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'เลือก',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildNotificationCard(BuildContext context, NotificationItem item) {
    final isSelected = _selectedIds.contains(item.id);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(item.id);
        } else {
          // เปลี่ยนสถานะเป็นอ่านแล้ว
          setState(() {
            item.isRead = true;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationDetailScreen(
                notification: item,
                user: widget.user,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF90CAF9).withOpacity(0.5)
              : !item.isRead
              ? const Color(0xFF85C3DF) // ยังไม่ได้อ่าน
              : const Color(0xFFBADEEE), // อ่านแล้ว
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Color(0xFF1976D2), width: 2)
              : null,
        ),

        child: Row(
          children: [
            // Checkbox (แสดงเฉพาะโหมดเลือก)
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Color(0xFF1976D2), width: 2),
                  ),
                  child: isSelected
                      ? Icon(Icons.circle, size: 16, color: Color(0xFF2374B5))
                      : null,
                ),
              ),

            // ICON
            Container(
              width: 50,
              height: 50,

              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  item.imagePath.isNotEmpty
                      ? item.imagePath
                      : 'assets/images/placeholder.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description.isNotEmpty ? item.description : '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Text(
              item.timestamp.isNotEmpty ? item.timestamp : '',
              style: const TextStyle(fontSize: 11),
            ),
          ],
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

// Notification Item Model
class NotificationItem {
  final String id;
  final String imagePath;
  final String? title;
  final String description;
  final String timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.imagePath,
    required this.title,
    required this.description,
    required this.timestamp,
    this.isRead = false,
  });
}