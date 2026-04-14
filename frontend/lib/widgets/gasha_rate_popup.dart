import 'package:flutter/material.dart';

class GashaRatePopup extends StatelessWidget {
  const GashaRatePopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const GashaRatePopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Mock data for groups
    final rareItems = [
      {'name': 'ชุดเดรส', 'rate': '0.0002%'},
      {'name': 'ผมสตรอเบอร์รี่', 'rate': '0.0005%'},
    ];

    final normalItems = [
      {'name': 'หน้าแบ๊ว', 'rate': '0.02%'},
      {'name': 'หน้าแบ๊ว', 'rate': '0.02%'},
      {'name': 'หน้าแบ๊ว', 'rate': '0.02%'},
      {'name': 'หน้าแบ๊ว', 'rate': '0.02%'},
      {'name': 'หน้าแบ๊ว', 'rate': '0.02%'},
      {'name': 'หน้าแบ๊ว', 'rate': '0.02%'},
      {'name': 'หน้าแบ๊ว', 'rate': '0.02%'},
      {'name': 'หน้าแบ๊ว', 'rate': '0.02%'},
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: Center(
        child: Container(
          width: size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 350, maxHeight: 450),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ------------------------------------------------
              // 1) พื้นหลัง Background Split
              // ------------------------------------------------
              Positioned.fill(
                child: Column(
                  children: [
                    Container(
                      height: 120, // ความสูงพื้นที่สีฟ้าเข้ม
                      color: const Color(0xFF9DD0E7),
                    ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFC6F4FF), // สีฟ้าอ่อน
                      ),
                    ),
                  ],
                ),
              ),

              // ------------------------------------------------
              // 2) Content (หัวข้อ + กล่องขาว)
              // ------------------------------------------------
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header "โอกาสได้รับ"
                  SizedBox(
                    height: 65,
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            'โอกาสได้รับ',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF002A50),
                              shadows: [
                                Shadow(
                                  color: Colors.white,
                                  offset: const Offset(1.5, 1.5),
                                  blurRadius: 1,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: const Offset(-1.5, -1.5),
                                  blurRadius: 1,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: const Offset(1.5, -1.5),
                                  blurRadius: 1,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: const Offset(-1.5, 1.5),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // ปุ่มปิด X
                        Positioned(
                          right: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.close,
                                color: Color.fromARGB(255, 255, 255, 255),
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // กล่องสีขาวด้านใน
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // หมวดแรร์
                            _buildCategory(
                              title: 'แรร์',
                              titleColor: Colors.black87,
                              underlineColor: const Color(
                                0xFFFF9800,
                              ), // เส้นขีดส้ม
                              iconPath: 'assets/images/design/design4.png',
                              items: rareItems,
                            ),
                            const SizedBox(height: 30),
                            // หมวดธรรมดา
                            _buildCategory(
                              title: 'ธรรมดา',
                              titleColor: Colors.black87,
                              underlineColor: const Color(
                                0xFF93C8D0,
                              ), // เส้นขีดฟ้า
                              iconPath: 'assets/images/design/design1.png',
                              items: normalItems,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategory({
    required String title,
    required Color titleColor,
    required Color underlineColor,
    required String iconPath,
    required List<Map<String, String>> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Row(
          children: [
            Image.asset(
              iconPath,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.star, color: Colors.orange, size: 44),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ],
        ),
        // Underline
        Container(
          margin: const EdgeInsets.only(top: 0.5, bottom: 6),
          height: 1,
          width: double.infinity,
          color: underlineColor,
        ),
        // Items
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                // Item Image
                Image.asset(
                  'assets/images/item/Ticket_energy_img.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.confirmation_num,
                    color: Colors.grey,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                // Item Name
                Expanded(
                  child: Text(
                    item['name']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444),
                    ),
                  ),
                ),
                // Item Rate
                Text(
                  item['rate']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}