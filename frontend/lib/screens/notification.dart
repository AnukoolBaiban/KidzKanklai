import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';

import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/screens/notification_details.dart';
import 'package:flutter_application_1/widgets/confirm_delete_popup.dart';

class NotificationScreen extends StatefulWidget {
  final User? user;

  const NotificationScreen({super.key, this.user});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Key _topBarKey = UniqueKey();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPressed = false;
  bool _isSelectionMode = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final list = await ApiService.getNotifications();

      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _markAsRead(int id) async {
    await ApiService.markNotificationRead(id);
    if (mounted) {
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == id);
        if (idx != -1) _notifications[idx].isRead = true;
      });
    }
  }

  Future<void> _deleteAllNotifications() async {
    final ok = await ApiService.deleteAllNotifications();
    if (!mounted) return;

    if (ok) {
      setState(() {
        _notifications.clear();
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบการแจ้งเตือนทั้งหมดแล้ว')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง')),
      );
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _deleteSelectedNotifications() async {
    final toDelete = Set<int>.from(_selectedIds);

    // ลบทีละรายการ
    final futures = toDelete.map((id) => ApiService.deleteNotification(id));
    await Future.wait(futures);

    if (!mounted) return;

    setState(() {
      _notifications.removeWhere((item) => toDelete.contains(item.id));
      _selectedIds.clear();
      _isSelectionMode = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ลบการแจ้งเตือนที่เลือกแล้ว')));
  }

  void _toggleSelection(int id) {
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
            child: Image.asset(
              'assets/images/background/bg1.png',
              fit: BoxFit.cover,
            ),
          ),

          _buildTopBar(),

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
                              const SizedBox(height: 30),

                              // Progress counter
                              Text(
                                'จำนวน ${_notifications.length}/100',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              // ListView
                              Expanded(
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF2374B5),
                                        ),
                                      )
                                    : _hasError
                                    ? _buildErrorState()
                                    : _notifications.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'ไม่มีการแจ้งเตือน',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      )
                                    : RefreshIndicator(
                                        onRefresh: _loadNotifications,
                                        color: const Color(0xFF2374B5),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                            bottom: 20,
                                          ),
                                          itemCount: _notifications.length,
                                          itemBuilder: (context, index) {
                                            return _buildNotificationCard(
                                              context,
                                              _notifications[index],
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      _buildHeaderTitle(),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildBottomButtons(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.black38),
          const SizedBox(height: 12),
          const Text(
            'ไม่สามารถโหลดข้อมูลได้',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
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
              onNotificationTapped: () {},
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

  Widget _buildBottomButtons() {
    if (_isSelectionMode) {
      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                onPressed: _toggleSelectionMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
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
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () {
                      ConfirmDeletePopup.show(
                        context,
                        title: 'ยืนยันที่จะลบการแจ้งเตือนที่เลือกหรือไม่?',
                        onConfirm: () {
                          Navigator.pop(context); // ปิด popup ก่อน
                          _deleteSelectedNotifications(); // ค่อยลบจริง
                        },
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA4444),
                disabledBackgroundColor: const Color(
                  0xFFEA4444,
                ).withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'ลบ (${_selectedIds.length})',
                style: const TextStyle(
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
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _notifications.isEmpty
                  ? null
                  : () {
                      ConfirmDeletePopup.show(
                        context,
                        onConfirm: () {
                          Navigator.pop(context); // ปิด popup ก่อน
                          _deleteAllNotifications(); // ค่อยลบจริง
                        },
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA4444),
                disabledBackgroundColor: const Color(
                  0xFFEA4444,
                ).withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'ลบทั้งหมด',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _notifications.isEmpty
                      ? [
                          const Color(0xFF556AEB).withOpacity(0.5),
                          const Color(0xFF59ABEC).withOpacity(0.5),
                        ]
                      : [const Color(0xFF556AEB), const Color(0xFF59ABEC)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                onPressed: _notifications.isEmpty ? null : _toggleSelectionMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
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

  Widget _buildNotificationCard(BuildContext context, NotificationModel item) {
    final isSelected = _selectedIds.contains(item.id);
    final isAchievement = item.type == 'achievement';

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(item.id);
        } else {
          // Mark as read ทันทีที่กดเปิด
          if (!item.isRead) {
            _markAsRead(item.id);
          }
          // เปิดหน้า detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationDetailScreen(
                notification: item,
                user: widget.user,
              ),
            ),
          ).then((_) {
            // Refresh หลังจากกลับมา
            if (mounted) {
              setState(() {
                _topBarKey = UniqueKey();
              });
              _loadNotifications();
            }
          });
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF90CAF9).withOpacity(0.5)
                  : !item.isRead
                  ? const Color(0xFF85C3DF)
                  : const Color(0xFFBADEEE),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: const Color(0xFF1976D2), width: 2)
                  : null,
            ),
            child: Row(
              children: [
                // Checkbox (โหมดเลือก)
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF1976D2),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.circle,
                              size: 16,
                              color: Color(0xFF2374B5),
                            )
                          : null,
                    ),
                  ),

                // ICON
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    item.iconPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.notifications,
                      size: 28,
                      color: Color(0xFF2374B5),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.title.isNotEmpty ? item.title : '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.detail.isNotEmpty ? item.detail : '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  item.shortRelativeTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: item.shortRelativeTime == '6 วันที่แล้ว'
                        ? Colors.red
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // จุดแดงแสดงว่ายังไม่อ่าน (มุมซ้ายบน)
          if (!item.isRead)
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE53935),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
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

// Notification Item Model (legacy — ยังคงไว้เพื่อรองรับ NotificationDetailScreen)
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

  /// สร้าง NotificationItem จาก NotificationModel (เพื่อส่งให้ NotificationDetailScreen)
  factory NotificationItem.fromModel(NotificationModel model) {
    return NotificationItem(
      id: model.id.toString(),
      imagePath: model.iconPath,
      title: model.title,
      description: model.detail,
      timestamp: model.shortRelativeTime,
      isRead: model.isRead,
    );
  }
}
