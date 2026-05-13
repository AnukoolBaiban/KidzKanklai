import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_application_1/api_service.dart';

import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/right_side_menu.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/character_widget.dart';
import 'package:flutter_application_1/widgets/reward_popup.dart';
import 'package:flutter_application_1/screens/loading.dart';
import 'package:flutter_application_1/services/audio_manager.dart';


class LobbyScreen extends StatefulWidget {
  final User? user;
  final bool showLoading;

  const LobbyScreen({Key? key, this.user, this.showLoading = false}) : super(key: key);

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  Key _topBarKey = UniqueKey();
  int _selectedIndex = 1;
  User? _user;
  late bool _isLoading;
  bool _hasUnclaimedAchievement = false;
  bool _hasUnclaimedQuest = false;

  void _onReturnFromOtherPage() {
    if (mounted) {
      setState(() {
        _selectedIndex = 1;
        _topBarKey = UniqueKey();
      });
      _loadUserData();
      _checkUnclaimedAchievements();
      _checkUnclaimedQuests();
    }
  }

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _isLoading = widget.showLoading; // แสดง Loading เฉพาะตอน login ครั้งแรก
    _loadUserData();
    // สั่งเช็คของรางวัลทันทีที่เปิดหน้านี้
    _checkDailyLoginRewards();
    _checkUnclaimedAchievements();
    _checkUnclaimedQuests();
    // _giveMeCoins(); // สำหรับเทสเพิ่มเหรียญ
    
    // 🌟 แอบสั่งให้ Backend เช็คและสร้างข้อสอบประจำสัปดาห์
    ApiService.generateWeeklyExams();

    // เล่นเพลง lobby ตรงนี้ด้วย เพื่อรองรับกรณี User login ค้างไว้
    // AuthGate render LobbyScreen โดยตรงโดยไม่ผ่าน navigation → Observer ไม่รู้ว่ามาถึง /lobby จึงไม่เล่นเพลง
    // ปลอดภัย: playBGM มี guard ตรวจสอบว่าเล่นเพลงเดิมอยู่แล้วหรือไม่ จึงไม่เล่นซ้ำซ้อน
    AudioManager().playBGM('lobby.mp3');
  }

  Future<void> _loadUserData() async {
    final profile = await ApiService.getProfile(0);
    if (mounted) {
      if (_isLoading) {
        // มาจาก login — หน่วงนิดให้ Loading screen โชว์ก่อน
        await Future.delayed(const Duration(milliseconds: 500));
      }
      setState(() {
        if (profile != null) {
          _user = profile;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _checkUnclaimedAchievements() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;
      
      final attainResponse = await Supabase.instance.client
          .from('attain')
          .select('status, reward_claimed')
          .eq('user_id', currentUserId)
          .eq('status', 'completed')
          .eq('reward_claimed', false)
          .limit(1);

      if (mounted) {
        setState(() {
          _hasUnclaimedAchievement = attainResponse.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error checking unclaimed achievements: $e');
    }
  }
  Future<void> _checkUnclaimedQuests() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await Supabase.instance.client
          .from('do_quests')
          .select('progress, quests(target_amount, type)')
          .eq('user_id', currentUserId)
          .neq('status', 'completed');

      bool hasUnclaimed = false;
      for (var row in response) {
        final progress = row['progress'] ?? 0;
        final quest = row['quests'];
        if (quest != null) {
          final target = quest['target_amount'] ?? 1;
          final type = quest['type'] ?? '';
          if ((type == 'ระบบ' || type == 'แนะนำ') && progress >= target) {
            hasUnclaimed = true;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasUnclaimedQuest = hasUnclaimed;
        });
      }
    } catch (e) {
      debugPrint('Error checking unclaimed quests: $e');
    }
  }

  // ฟังก์ชันเช็คและโชว์ป๊อปอัป
  Future<void> _checkDailyLoginRewards() async {
    final apiRewards = await ApiService.claimLoginBonus();

    if (apiRewards.isNotEmpty && mounted) {
      List<RewardData> collectedRewards = [];

      for (var reward in apiRewards) {
        collectedRewards.add(
          RewardData.item(
            name: reward['name'],
            amount: reward['added'],
            image: reward['image'], // 🌟 จับค่าใส่ตรงๆ ได้เลย โค้ดสั้นลงมาก!
          ),
        );
      }

      await RewardPopup.show(context, rewards: collectedRewards);
    }
  }

    // Right Menu Items
  List<MenuItem> get _menuItems => [
    MenuItem(
      imagePath: "assets/images/icon/iconAchievement.png",
      label: 'ความสำเร็จ',
      hasNotification: _hasUnclaimedAchievement,
      onTap: () {
        Navigator.pushNamed(context, '/achievement').then((_) => _onReturnFromOtherPage());
      },
    ),
    MenuItem(
      imagePath: "assets/images/icon/iconQuest.png",
      label: 'ภารกิจ',
      hasNotification: _hasUnclaimedQuest,
      onTap: () {
        Navigator.pushNamed(context, '/allquest').then((_) => _onReturnFromOtherPage());
      },
    ),
    MenuItem(
      imagePath: "assets/images/item/Gasha.png",
      label: 'กล่องสุ่ม',
      onTap: () {
        Navigator.pushNamed(context, '/gasha').then((_) => _onReturnFromOtherPage());
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _isLoading
          ? const LoadingScreen(key: ValueKey('loading'), isStandalone: false)
          : Scaffold(
              key: const ValueKey('lobby'),
              body: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/background/bg3.png"),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(
                  children: [
            // Top Bar - ใช้ CustomTopBar (หุ้มด้วยแถบสีดำบางๆ ให้เหมือนหน้าภารกิจ)
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              color: Colors.black.withOpacity(0.4),
              child: CustomTopBar(
                  key: _topBarKey,
                  onNotificationTapped: () {
                    Navigator.pushNamed(context, '/notification').then((_) => _onReturnFromOtherPage());
                  },
                  onSettingsTapped: () {
                    Navigator.pushNamed(context, '/setting').then((_) => _onReturnFromOtherPage());
                  },
                ),
              ),

              // Main Content
              Expanded(
                // Added Expanded to fill remaining space
                child: Stack(
                  alignment: Alignment.center, // Center the character
                  children: [
                    // Character Widget - อยู่ชั้นล่างสุด
                    Positioned(
                      bottom: _user?.bodyType.toUpperCase() == 'ADULT' ? -5 :
                              _user?.bodyType.toUpperCase() == 'TEEN' ? -40 : -150, // ร่างเด็กตัวเล็กเลยต้องกดลงมา ส่วนวัยรุ่น/ผู้ใหญ่ขยับขึ้นมาหน่อยไม่ให้ขาหลุดขอบ
                      child: _isLoading || _user == null
                          ? const SizedBox() // Or CircularProgressIndicator() if you want to see it loading
                          : CharacterWidget(
                              height: 600,
                              width: 500,
                              user: _user, // Pass Updated User to Character
                            ),
                    ),

                    // Right Side Menu Component
                    RightSideMenu(menuItems: _menuItems),
                  ],
                ),
              ),

              // Bottom Navigation
              SafeArea(
                top: false,
                child: CustomBottomNavigationBar(
                  selectedIndex: _selectedIndex,
                  onItemTapped: (index) {
                    if (index == 1) return;

                    setState(() {
                      _selectedIndex = index;
                    });

                    switch (index) {
                      case 0:
                        Navigator.pushNamed(context, '/fashion').then((_) => _onReturnFromOtherPage());
                        break;
                      case 2:
                        Navigator.pushNamed(context, '/map').then((_) => _onReturnFromOtherPage());
                        break;
                      case 3:
                        Navigator.pushNamed(context, '/club').then((_) => _onReturnFromOtherPage());
                        break;
                    }
                  },
                  onAvatarTapped: () {
                    Navigator.pushNamed(context, '/profile').then((_) => _onReturnFromOtherPage());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
