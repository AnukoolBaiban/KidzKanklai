import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/level_up_popup.dart';
import 'package:flutter_application_1/widgets/character_up_popup.dart';

class RewardPopup extends StatefulWidget {
  // 🌟 เปลี่ยนมารับข้อมูลเป็น List ของ RewardData แทน
  final List<RewardData> rewards;
  final VoidCallback? onClose;

  const RewardPopup({
    Key? key,
    required this.rewards,
    this.onClose,
  }) : super(key: key);

  @override
  State<RewardPopup> createState() => _RewardPopupState();

  static Future<void> show(
    BuildContext context, {
    required List<RewardData> rewards,
    bool leveledUp = false,
    int baseLevel = 0,
    int newLevel = 0,
    User? user,
    VoidCallback? onClose,
  }) async {
    debugPrint('🎁 [RewardPopup.show] START — leveledUp=$leveledUp, baseLv=$baseLevel, newLv=$newLevel');

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => RewardPopup(
        rewards: rewards,
        onClose: () {
          debugPrint('🎁 [RewardPopup.show] onClose called — popping dialog');
          Navigator.pop(dialogContext);
          onClose?.call();
        },
      ),
    );

    debugPrint('🎁 [RewardPopup.show] RewardPopup closed — leveledUp=$leveledUp, context.mounted=${context.mounted}');

    if (leveledUp && context.mounted) {
      // หน่วงเวลาเล็กน้อยเพื่อป้องกัน ghost tap จาก RewardPopup ตกทะลุไปยัง LevelUpPopup
      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint('🎁 [RewardPopup.show] After delay — context.mounted=${context.mounted}');
      if (!context.mounted) return;

      int getModelGroup(int lv) {
        if (lv >= 30) return 2;
        if (lv >= 15) return 1;
        return 0;
      }
      
      final isEvolution = getModelGroup(newLevel) > getModelGroup(baseLevel);
      debugPrint('🎁 [RewardPopup.show] isEvolution=$isEvolution (baseGroup=${getModelGroup(baseLevel)}, newGroup=${getModelGroup(newLevel)})');

      if (isEvolution) {
        debugPrint('🎁 [RewardPopup.show] Showing CharacterUpPopup...');
        final freshUser = await ApiService.getProfile(0);
        if (context.mounted) {
          await CharacterUpPopup.show(
            context,
            baseLevel: baseLevel,
            newLevel: newLevel,
            user: freshUser ?? user,
            onTapContinue: () {},
          );
        }
      } else {
        debugPrint('🎁 [RewardPopup.show] Showing LevelUpPopup...');
        if (context.mounted) {
          await LevelUpPopup.show(
            context,
            baseLevel: baseLevel,
            newLevel: newLevel,
            onTapContinue: () {},
          );
        }
      }
      debugPrint('🎁 [RewardPopup.show] LevelUp/CharacterUp popup finished');
    } else {
      debugPrint('🎁 [RewardPopup.show] SKIPPED level up popup — leveledUp=$leveledUp, mounted=${context.mounted}');
    }

    debugPrint('🎁 [RewardPopup.show] END');
  }
}

class _RewardPopupState extends State<RewardPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _canClose = false; // ป้องกันการกดปิดเร็วเกินไป

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // อนุญาตให้ปิดได้หลังจาก animation เล่นเสร็จ (800ms)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _canClose = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _canClose
          ? () {
              widget.onClose?.call();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              // ลบ height แบบ fix ออก เพื่อให้กล่องยืดตามจำนวนไอเทม
              constraints: const BoxConstraints(maxHeight: 500, minHeight: 180),
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // แสงฟุ้งพื้นหลัง
                  Container(  
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.4),
                          blurRadius: 100,
                          spreadRadius: 60,
                        ),
                      ],
                    ),
                  ),

                  // Main Container
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20), // เพิ่ม padding ด้านบนนิดหน่อย
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(5, 0, 0, 0),
                          Color.fromARGB(50, 0, 0, 0),
                          Color.fromARGB(5, 0, 0, 0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
                        bottom: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ได้รับรางวัล',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // 🌟 ส่วนที่แสดงไอเทมทั้งหมดพร้อมกันโดยใช้ Wrap
                        Wrap(
                          spacing: 16, // ระยะห่างแนวนอนระหว่างไอเทม
                          runSpacing: 16, // ระยะห่างแนวตั้ง (กรณีไอเทมเยอะจนปัดบรรทัดใหม่)
                          alignment: WrapAlignment.center,
                          children: widget.rewards.map((reward) {
                            return _buildRewardIcon(reward);
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        AnimatedOpacity(
                          opacity: _canClose ? 1.0 : 0.3,
                          duration: const Duration(milliseconds: 300),
                          child: const Text(
                            'แตะหน้าจอเพื่อดำเนินการต่อ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Header Title (รับรางวัลสำเร็จ)
                  _buildHeader(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🌟 ฟังก์ชันวาดกล่องไอเทมแต่ละชิ้น
  Widget _buildRewardIcon(RewardData reward) {
    String imageToShow;
    if (reward.type == 'COIN') {
      imageToShow = 'assets/images/item/coin.png';
    } else if (reward.type == 'EXP') {
      imageToShow = 'assets/images/item/EXP.png';
    } else {
      imageToShow = reward.itemImage ?? "assets/images/item/Gasha.png";
    }

    return Container(
      width: 70, // ปรับขนาดกล่องให้เล็กลงนิดนึงเพื่อเรียงได้หลายอัน
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imageToShow,
            width: 35,
            height: 35,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.stars, size: 35, color: Color(0xFFFFA726));
            },
          ),
          const SizedBox(height: 4),
          Text(
            '+${reward.amount}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: -60,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ดาวดวงที่ 1
              Image.asset(
                'assets/images/icon/Star11.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              
              Text(
                'รับรางวัลสำเร็จ',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(width: 4),
              
              // ดาวดวงที่ 2
              Image.asset(
                'assets/images/icon/Star11.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper class สำหรับ Reward data (เหมือนเดิม)
class RewardData {
  final String type;
  final int amount;
  final String? itemName;
  final String? itemImage;

  RewardData({
    required this.type,
    required this.amount,
    this.itemName,
    this.itemImage,
  });

  factory RewardData.exp(int amount) => RewardData(type: 'EXP', amount: amount);
  factory RewardData.coin(int amount) => RewardData(type: 'COIN', amount: amount);
  factory RewardData.ticket(int amount) => RewardData(type: 'TICKET', amount: amount);
  factory RewardData.item({required String name, required int amount, String? image}) {
    return RewardData(type: 'ITEM', amount: amount, itemName: name, itemImage: image);
  }
}