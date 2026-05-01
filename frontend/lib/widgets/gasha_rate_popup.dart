import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';

class GashaRatePopup extends StatefulWidget {
  const GashaRatePopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const GashaRatePopup(),
    );
  }

  @override
  State<GashaRatePopup> createState() => _GashaRatePopupState();
}

class _GashaRatePopupState extends State<GashaRatePopup> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _epicItems = [];
  List<Map<String, dynamic>> _rareItems = [];
  List<Map<String, dynamic>> _commonItems = [];

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    final rates = await ApiService.getGachaRates();
    if (mounted) {
      setState(() {
        _epicItems = rates.where((it) => it['rarity'] == 'EPIC').toList();
        _rareItems = rates.where((it) => it['rarity'] == 'RARE').toList();
        _commonItems = rates.where((it) => it['rarity'] != 'EPIC' && it['rarity'] != 'RARE').toList();
        _isLoading = false;
      });
    }
  }

  String _getImagePath(Map<String, dynamic> item) {
    final String itemName = item['name'] ?? '';
    final int categoryId = item['category_id'] ?? 0;
    
    if (categoryId == 10) {
      return 'assets/images/Fashion/Outfit/$itemName.PNG';
    } else if (categoryId == 12) {
      return 'assets/images/Fashion/HairStyle/$itemName.PNG';
    } else if (categoryId == 13) {
      return 'assets/images/Fashion/FaceStyle/$itemName.PNG';
    }
    return 'assets/images/item/EXP.png';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: Center(
        child: Container(
          width: size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 350, maxHeight: 550),
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
                        const Center(
                          child: Text(
                            'โอกาสได้รับ',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF002A50),
                              shadows: [
                                Shadow(
                                  color: Colors.white,
                                  offset: Offset(1.5, 1.5),
                                  blurRadius: 1,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: Offset(-1.5, -1.5),
                                  blurRadius: 1,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: Offset(1.5, -1.5),
                                  blurRadius: 1,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  offset: Offset(-1.5, 1.5),
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
                      child: _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(scrollbars: false),
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  // หมวดอีปิค (Epic)
                                  if (_epicItems.isNotEmpty) ...[
                                    _buildCategory(
                                      title: 'อีปิค (Epic) - รวม 1%',
                                      titleColor: Colors.black87,
                                      underlineColor: const Color(0xFFFF4081),
                                      iconPath: 'assets/images/icon/Epic-icon.png',
                                      fallbackIcon: Icons.stars,
                                      iconColor: Colors.pinkAccent,
                                      items: _epicItems,
                                    ),
                                    const SizedBox(height: 30),
                                  ],
                                  // หมวดแรร์ (Rare)
                                  if (_rareItems.isNotEmpty) ...[
                                    _buildCategory(
                                      title: 'แรร์ (Rare) - รวม 9%',
                                      titleColor: Colors.black87,
                                      underlineColor: const Color(0xFFFF9800),
                                      iconPath: 'assets/images/design/design4.png',
                                      fallbackIcon: Icons.star,
                                      iconColor: Colors.orange,
                                      items: _rareItems,
                                    ),
                                    const SizedBox(height: 30),
                                  ],
                                  // หมวดธรรมดา (Common)
                                  if (_commonItems.isNotEmpty) ...[
                                    _buildCategory(
                                      title: 'ธรรมดา (Common) - รวม 90%',
                                      titleColor: Colors.black87,
                                      underlineColor: const Color(0xFF93C8D0),
                                      iconPath: 'assets/images/design/design1.png',
                                      fallbackIcon: Icons.star_border,
                                      iconColor: Colors.blueAccent,
                                      items: _commonItems,
                                    ),
                                  ],
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
    required IconData fallbackIcon,
    required Color iconColor,
    required List<Map<String, dynamic>> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Row(
          children: [
            Image.asset(
              iconPath,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(fallbackIcon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ],
        ),
        // Underline
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          height: 1,
          width: double.infinity,
          color: underlineColor,
        ),
        // Items
        ...items.map((item) {
          final itemNameStr = item['name']?.toString() ?? '';
          final itemDescStr = item['description']?.toString() ?? itemNameStr;
          final itemRate = item['rate'] != null
              ? '${(item['rate'] as num).toStringAsFixed(1)}%'
              : '0%';
          final itemImagePath = _getImagePath(item);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Item Image
                Image.asset(
                  itemImagePath,
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.inventory_2,
                    color: Colors.grey,
                    size: 56,
                  ),
                ),
                const SizedBox(width: 16),
                // Item Name
                Expanded(
                  child: Text(
                    itemDescStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444),
                    ),
                  ),
                ),
                // Item Rate
                Text(
                  itemRate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}