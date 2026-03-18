import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/screens/lobby.dart';
import 'package:flutter_application_1/widgets/reward_popup.dart';

class AchievementScreen extends StatefulWidget {
  final User? user;
  final VoidCallback? onClose;
  const AchievementScreen({super.key, this.user, this.onClose});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  int _selectedIndex = 1;
  int? _expandedAchievementIndex;
  bool _isPressed = false;
  
  bool _isLoading = true;
  List<Achievement> achievements = [];

  @override
  void initState() {
    super.initState();
    _fetchAchievements();
  }

  // 🌟 ฟังก์ชันดึงข้อมูลแบบอัปเดตใหม่ (เช็คข้อมูลจากตาราง attain ด้วย)
  Future<void> _fetchAchievements() async {
    try {
      // 1. ดึง ID ของผู้เล่นปัจจุบันจาก Supabase Auth
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      // 2. ดึงข้อมูล achievements และของรางวัล
      final response = await Supabase.instance.client
          .from('achievements')
          .select('''
            id, 
            name, 
            description, 
            image, 
            give (
              quantity,
              items (
                name,
                image
              )
            )
          ''')
          .order('id', ascending: true);

      // 3. 🌟 ดึงข้อมูลสถานะ "รับรางวัลหรือยัง" จากตาราง attain
      List<dynamic> attainResponse = [];
      if (currentUserId != null) {
        attainResponse = await Supabase.instance.client
            .from('attain')
            .select('achievement_id, status, reward_claimed')
            .eq('user_id', currentUserId);
      }

      // สร้าง Map เพื่อให้เช็คค่าง่ายๆ ว่าเควสไหนรับรางวัลไปแล้วบ้าง
      final attainMap = {
        for (var item in attainResponse)
          item['achievement_id'].toString(): item
      };

      List<Achievement> loadedAchievements = [];

      for (var row in response) {
        final achievementIdStr = row['id'].toString();
        AchievementReward? reward;

        if (row['give'] != null && (row['give'] as List).isNotEmpty) {
          final giveData = (row['give'] as List).first;
          final int quantity = giveData['quantity'] ?? 0;
          
          final itemData = giveData['items'];
          String itemName = "Item";
          String itemImage = "assets/images/item/default_item.png";

          if (itemData != null) {
             itemName = itemData['name'] ?? "Item";
             if (itemData['image'] != null) {
               itemImage = itemData['image'];
             }
          }

          reward = AchievementReward(
            amount: quantity,
            name: itemName,
            imagePath: itemImage,
          );
        }

        // 🌟 ตรวจสอบสถานะทั้ง "ทำเสร็จหรือยัง" และ "รับของหรือยัง"
        final userAttainData = attainMap[achievementIdStr];
        bool isDone = false;
        bool hasClaimedReward = false;
        
        if (userAttainData != null) {
          isDone = userAttainData['status'] == 'completed';
          hasClaimedReward = userAttainData['reward_claimed'] ?? false;
        }

        loadedAchievements.add(Achievement(
          id: achievementIdStr,
          name: row['name'] ?? 'ไม่มีชื่อ',
          description: row['description'] ?? 'ไม่มีรายละเอียด',
          imagePath: row['image'],
          isUnlocked: true,
          isCompleted: isDone, // 🌟 ส่งสถานะทำเสร็จไปให้ UI
          // 🌟 จุดแดงจะขึ้นก็ต่อเมื่อ "ทำเสร็จแล้ว" และ "ยังไม่ได้รับรางวัล" เท่านั้น
          hasNotification: isDone && !hasClaimedReward, 
          isClaimed: hasClaimedReward, 
          reward: reward,
        ));
      }

      if (mounted) {
        setState(() {
          achievements = loadedAchievements;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching achievements: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/background/bg4.png', fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 200),
                    padding: const EdgeInsets.all(20),
                    height: MediaQuery.of(context).size.height * 0.65,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'จำนวนทั้งหมด ${achievements.length} รายการ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : achievements.isEmpty
                                  ? const Center(child: Text("ไม่พบข้อมูลความสำเร็จ"))
                                  : SingleChildScrollView(
                                      child: Column(children: _buildAchievementList()),
                                    ),
                        ),
                      ],
                    ),
                  ),
                  _buildHeaderTitle(),
                ],
              ),
            ),
          ),
          _buildTopBar(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0, 
            child: SafeArea( 
              top: false, 
              child: CustomBottomNavigationBar(
                selectedIndex: _selectedIndex,
                onItemTapped: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  switch (index) {
                    case 0: Navigator.pushNamed(context, '/fashion'); break;
                    case 1: Navigator.pushNamed(context, '/lobby'); break;
                    case 2: Navigator.pushNamed(context, '/map'); break;
                    case 3: Navigator.pushNamed(context, '/club'); break;
                  }
                },
                onAvatarTapped: () => Navigator.pushNamed(context, '/profile'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAchievementList() {
    List<Widget> widgets = [];
    for (int i = 0; i < achievements.length; i += 3) {
      widgets.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int j = i; j < i + 3 && j < achievements.length; j++)
              Expanded(child: _buildAchievementItem(achievements[j], j)),
            for (int k = achievements.length - i; k < 3 && i + k < i + 3; k++)
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (_expandedAchievementIndex != null &&
          _expandedAchievementIndex! >= i &&
          _expandedAchievementIndex! < i + 3) {
        widgets.add(_buildAchievementDetail(achievements[_expandedAchievementIndex!]));
      }
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
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
            height: screenHeight * 0.098, // responsive
            color: Colors.black.withOpacity(0.4),
            alignment: Alignment.bottomCenter,
            child: CustomTopBar(
              onNotificationTapped: () {
                Navigator.pushNamed(context, '/notification');
              },
              onSettingsTapped: () {
                Navigator.pushNamed(context, '/setting');
              },
            ),
          ),

          // เรียก Back Button
          _buildBackButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ขนาดปุ่มตามขนาดจอ
    final buttonSize = screenWidth * 0.12; // 12% ของความกว้างจอ
    final topPadding = screenHeight * 0.010;

    return Padding(
      padding: EdgeInsets.only(left: screenWidth * 0.05, top: topPadding),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () async {
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LobbyScreen(user: widget.user),
            ),
          ).then((_) {
            setState(() => _isPressed = false);
          });
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


  Widget _buildAchievementItem(Achievement achievement, int index) {
    final isExpanded = _expandedAchievementIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _expandedAchievementIndex = isExpanded ? null : index;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(isExpanded ? 4 : 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isExpanded
                    ? const LinearGradient(
                        colors: [Color(0xFFCEFFB2), Color(0xFF75C6EA)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
              ),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: achievement.isUnlocked ? Colors.white : const Color(0xFFC2E0E5),
                ),
                child: Center(
                  child: achievement.isUnlocked && achievement.imagePath != null
                      ? ClipOval(
                          child: Image.asset(
                            achievement.imagePath!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildLockedIcon(),
                          ),
                        )
                      : _buildLockedIcon(),
                ),
              ),
            ),
            if (achievement.hasNotification && achievement.isUnlocked && !achievement.isClaimed)
              Positioned(
                top: 5,
                right: 5,
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
      ),
    );
  }

  Widget _buildLockedIcon() {
    return const Text(
      '?',
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    );
  }

  Widget _buildAchievementDetail(Achievement achievement) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFB3E5FC).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            achievement.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            achievement.description,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // 🌟 1. กรณีที่ "ยังไม่เคยกดรับรางวัล" (อาจจะทำเสร็จแล้ว หรือยังไม่เสร็จก็ได้)
          if (achievement.reward != null && !achievement.isClaimed)
            Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        achievement.reward!.imagePath,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.stars, size: 40, color: Color(0xFFFFA726));
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${achievement.reward!.amount}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // 🌟 ปุ่มรับรางวัล (เช็ค isCompleted เพื่อเปลี่ยนสีและปิดปุ่ม)
                Container(
                  decoration: BoxDecoration(
                    // ถ้าทำเสร็จแล้ว (isCompleted) ให้เป็นสีเขียว ถ้ายังไม่เสร็จให้เป็นสีเทา
                    gradient: achievement.isCompleted
                        ? const LinearGradient(
                            colors: [Color(0xFF85D755), Color(0xFF34C759)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                    color: achievement.isCompleted ? null : Colors.grey.shade400,
                    border: Border.all(color: Colors.white, width: 1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: ElevatedButton(
                    // ถ้า isCompleted เป็น false ให้ onPressed เป็น null (กดไม่ได้)
                    onPressed: achievement.isCompleted
                        ? () async {
                            final rewardsList = await ApiService.claimAchievementReward(int.parse(achievement.id));

                            if (rewardsList != null && mounted) {
                              setState(() {
                                achievement.isClaimed = true;
                                achievement.hasNotification = false;
                              });

                              if (rewardsList.isNotEmpty) {
                                List<RewardData> popupRewards = rewardsList.map((r) {
                                  return RewardData.item(
                                    name: r['name'],
                                    amount: r['added'],
                                    image: r['image'] ?? 'assets/images/item/default_item.png',
                                  );
                                }).toList();
                                await RewardPopup.show(context, rewards: popupRewards);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('สำเร็จ! แต่ไม่มีข้อมูลของรางวัลในฐานข้อมูล')),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ยังทำภารกิจไม่สำเร็จ หรือรับรางวัลไปแล้ว')),
                                );
                              }
                            }
                          }
                        : null, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent, // ซ่อนพื้นหลังตอนกดไม่ได้
                      disabledForegroundColor: Colors.white70, // สีข้อความตอนกดไม่ได้
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      achievement.isCompleted ? 'รับรางวัล' : 'ยังไม่สำเร็จ',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

          // 🌟 2. ถ้าเคยกด Claimed ไปแล้ว ให้โชว์กล่องมีติ๊กถูกแทน
          if (achievement.isClaimed)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        achievement.reward?.imagePath ?? "assets/images/item/default_item.png",
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.stars, size: 40, color: Color(0xFFFFA726));
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${achievement.reward?.amount ?? 0}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 45,
                  right: -10,
                  child: Image.asset(
                    'assets/images/icon/check.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Positioned(
      top: 175,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionalTranslation(
          translation: const Offset(0, -0.5),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(80, 15, 30, 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF005395), Color(0xFF2374B5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Text(
                  "ความสำเร็จ",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                ),
              ),
              Positioned(
                left: 5,
                top: 0,
                child: Image.asset(
                  'assets/images/icon/iconAchievement.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String? imagePath;
  final bool isUnlocked;
  final bool isCompleted; // 🌟 เพิ่มตัวแปรนี้
  bool hasNotification;
  final AchievementReward? reward;
  bool isClaimed;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    this.imagePath,
    required this.isUnlocked,
    this.isCompleted = false, // 🌟 ค่าเริ่มต้นคือยังไม่เสร็จ
    required this.hasNotification,
    this.reward,
    this.isClaimed = false,
  });
}

class AchievementReward {
  final int amount;
  final String name;
  final String imagePath;

  AchievementReward({
    required this.amount,
    this.name = 'Item',
    this.imagePath = 'assets/images/item/default_item.png',
  });
}