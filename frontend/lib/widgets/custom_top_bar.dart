import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  int _coins = 0;
  int _tickets = 0; // QUEST_TICKET (id: 17)
  int _vouchers = 0; // EXAM_TICKET (id: 18)

  // ⚠️ กำหนด ID ของ Coin ในฐานข้อมูล
  final int _coinItemId = 20; 

  @override
  void initState() {
    super.initState();
    _fetchInventoryData();
  }

  Future<void> _fetchInventoryData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('collect')
          .select('item_id, quantity')
          .eq('user_id', user.id)
          .inFilter('item_id', [_coinItemId, 17, 18]); 

      if (mounted) {
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
      }
    } catch (e) {
      debugPrint('Error fetching top bar inventory: $e');
    }
  }

  // 🌟 ฟังก์ชันช่วยจัด Format ตัวเลขให้มีลูกน้ำ (คอมมา) ถ้าเกินหลักพัน (Option เสริม)
  String _formatNumber(int number) {
    if (number >= 1000) {
      // แปลงเป็น 1.2K หรือ 10K เพื่อประหยัดพื้นที่ 
      // (ถ้าอยากให้โชว์เต็มๆ เช่น 10,000 ให้เอาบล็อก if นี้ออกได้เลยครับ)
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), // 🌟 ลด padding แนวนอนลง
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
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 🌟 ใช้ spaceEvenly ให้เกลี่ยระยะห่างเท่าๆ กัน
                children: [
                  Expanded( // 🌟 ใส่ Expanded ให้ไอเทมยืดหยุ่น
                    child: _buildTopBarItem(
                      imagePath: 'assets/images/item/coin.png',
                      value: _formatNumber(_coins), // โชว์ค่า Coin
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey[300],
                  ),
                  Expanded( // 🌟 ใส่ Expanded
                    child: _buildTopBarItem(
                      imagePath: 'assets/images/item/Ticket_quest_img.png',
                      value: '$_tickets/7', 
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey[300],
                  ),
                  Expanded( // 🌟 ใส่ Expanded
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

  Widget _buildTopBarItem({
    required String imagePath,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // 🌟 ลด padding ข้างในลง
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 🌟 จัดให้อยู่ตรงกลางของพื้นที่ที่เหลือ
        children: [
          Image.asset(
            imagePath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.image_not_supported, size: 20, color: Colors.grey);
            },
          ),
          const SizedBox(width: 4),
          // 🌟 ใส่ Flexible และ FittedBox เพื่อย่อขนาดข้อความอัตโนมัติถ้าที่เต็ม!
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1, // บังคับให้อยู่บรรทัดเดียว
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
            return const Icon(Icons.settings, size: 25, color: Color(0xFF002A50));
          },
        ),
      ),
    );
  }
}