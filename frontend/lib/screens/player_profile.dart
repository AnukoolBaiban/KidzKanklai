import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image; 
import 'package:flutter_application_1/config/rive_cache.dart'; 
import '../widgets/character_widget.dart';
import 'package:flutter_application_1/api_service.dart' as api;
import 'loading.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String playerId; // 🌟 รับ UUID ของคนที่เราจะดูโปรไฟล์

  const PlayerProfileScreen({super.key, required this.playerId});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isBackPressed = false;
  bool _isLoading = true;

  // --- Profile Data ---
  String _displayName = "Loading...";
  String _displayBio = "กำลังโหลดข้อมูล...";
  String _uid = "Loading...";

  // --- Character Stats & Level Data ---
  int _level = 1;
  int _currentExp = 0; 
  int _nextLevelExp = 40; 
  double _expPercent = 0.0; 

  String _intStat = "10";
  String _strStat = "10";
  String _creStat = "10";

  // --- Character State ---
  api.User? _targetUser;

  // --- Achievement Data ---
  int _totalAchievements = 18; 
  int _unlockedAchievements = 0;
  List<String> _achievementImages = [];

  @override
  void initState() {
    super.initState();
    _uid = widget.playerId.substring(0, 8); // ตัดเอาแค่ 8 ตัวแรกมาโชว์เป็น UID
    _fetchPlayerProfile();
  }

  void _updateLevelUI(int dbLevel, int totalExp) {
    int remainingExp = totalExp;
    int requiredExpForNextLevel = 0;

    for (int i = 1; i < dbLevel; i++) {
      int expUsed = 0;
      if (i < 6) {
        expUsed = 40 * i;
      } else {
        expUsed = 200 + (i * i);
      }
      remainingExp -= expUsed;
    }

    if (dbLevel < 6) {
      requiredExpForNextLevel = 40 * dbLevel;
    } else {
      requiredExpForNextLevel = 200 + (dbLevel * dbLevel);
    }

    if (mounted) {
      setState(() {
        _level = dbLevel; 
        _currentExp = remainingExp; 
        _nextLevelExp = requiredExpForNextLevel; 
        
        _expPercent = (_nextLevelExp > 0)
            ? (_currentExp / _nextLevelExp).clamp(0.0, 1.0)
            : 0.0;
      });
    }
  }

  // 🌟 1. อัปเดตฟังก์ชันดึงข้อมูลให้ไปหาชุดจากตาราง wear
  Future<void> _fetchPlayerProfile() async {
    try {
      final targetUserId = widget.playerId;

      // 1. ดึงข้อมูล Profile พื้นฐาน
      final profileData = await _supabase
          .from('user_profiles')
          .select('name, detail') 
          .eq('id', targetUserId)
          .maybeSingle();

      if (profileData == null) {
        if (mounted) {
          setState(() {
            _displayName = "ไม่พบข้อมูลผู้ใช้";
            _displayBio = "ไม่สามารถดึงข้อมูลได้ (อาจติดสิทธิ์ RLS)";
          });
        }
        return; 
      }

      if (mounted) {
        setState(() {
          _displayName = profileData['name'] ?? "No Name";
          _displayBio = profileData['detail'] ?? "ยังไม่มีคำแนะนำตัว";
        });
      }

      // 2. ดึงข้อมูล Character และค่าเริ่มต้น (เพิ่มดึง id, skin_color, emotion มาด้วย)
      final charData = await _supabase
          .from('characters')
          .select('id, level, experience, intelligence, strength, creative, body_type, skin_color, emotion') 
          .eq('user_id', targetUserId)
          .maybeSingle();

      if (charData != null) {
        final charId = charData['id'];

        // ตั้งค่าตัวละครเริ่มต้น (อิงจาก characters)
        String eqSkin = charData['skin_color']?.toString() ?? '';
        String eqFace = charData['emotion']?.toString() ?? '';
        String eqHair = '';
        String eqOutfit = '';

        // 🌟 ดึงข้อมูลของสวมใส่จากตาราง wear โดย Join กับตาราง items เพื่อเอารูป
        if (charId != null) {
          final wearResponse = await _supabase
              .from('wear')
              .select('type, items(name, image)')
              .eq('character_id', charId);

          for (var w in wearResponse as List<dynamic>) {
            final type = w['type']?.toString().toLowerCase() ?? '';
            final itemData = w['items'];
            if (itemData != null) {
              final itemVal = itemData['name']?.toString() ?? itemData['image']?.toString() ?? '';
              
              if (type == 'hair') eqHair = itemVal;
              if (type == 'face' || type == 'emotion') eqFace = itemVal;
              if (type == 'skin') eqSkin = itemVal;
              if (type == 'cloth' || type == 'outfit' || type == 'clothes') eqOutfit = itemVal;
            }
          }
        }

        final dbLevel = charData['level'] as int? ?? 1;
        final totalExp = charData['experience'] as int? ?? 0;

        // อัปเดตข้อมูลเข้า State
        if (mounted) {
          setState(() {
            _intStat = charData['intelligence'].toString();
            _strStat = charData['strength'].toString();
            _creStat = charData['creative'].toString();
            
            _targetUser = api.User(
               id: 0, username: '', email: '', exp: totalExp, coins: 0, tickets: 0, vouchers: 0, bio: '', soundBGM: 0, soundSFX: 0, statIntellect: 0, statStrength: 0, statCreativity: 0,
               level: dbLevel,
               equippedSkin: eqSkin,
               equippedHair: eqHair,
               equippedFace: eqFace,
               equippedOutfit: eqOutfit,
               bodyType: charData['body_type']?.toString() ?? 'KID',
            );
          });
        }

        _updateLevelUI(dbLevel, totalExp); 
      }

      // 3. ดึงข้อมูล Achievement
      final allAchResponse = await _supabase.from('achievements').select('id');
      final int totalAchCount = allAchResponse.length; 

      final userAchResponse = await _supabase
          .from('attain') 
          .select('achievements ( image )') 
          .eq('user_id', targetUserId)
          .inFilter('status', ['completed', 'claimed']); 

      List<String> unlockedImages = [];
      for (var row in userAchResponse) {
        final achData = row['achievements'];
        if (achData != null && achData['image'] != null) {
          unlockedImages.add(achData['image']);
        }
      }

      if (mounted) {
        setState(() {
          _totalAchievements = totalAchCount;
          _unlockedAchievements = unlockedImages.length;
          _achievementImages = unlockedImages;
        });
      }

    } catch (e) {
      debugPrint('🚨 Error fetching player profile: $e');
      if (mounted) {
        setState(() {
          _displayName = "เกิดข้อผิดพลาด";
          _displayBio = "โปรดเช็ค Debug Console เพื่อดูสาเหตุที่แท้จริง";
        });
      }
    } finally {
      if (mounted) {
        // ให้หน่วงเวลาโหลดนิดนึงเพื่อให้แอนิเมชัน Loading โชว์และโมเดลพร้อม
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
              key: const ValueKey('profile'),
              backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          // Background Image
          SizedBox.expand(
            child: Image.asset(
              'assets/images/background/bg4.png',
              fit: BoxFit.cover,
            ),
          ),
          
          Column(
            children: [
              _buildTopBar(),
              
              // ปุ่มย้อนกลับ (เพิ่มเข้ามาเพื่อให้กดออกได้)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 10.0),
                  child: _buildBackButton(),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, left: 12, right: 12, bottom: 40), 
                  child: Column(
                    children: [
                      _buildProfileBox(),
                      const SizedBox(height: 20), 
                      _buildStatBox(),
                      const SizedBox(height: 20), 
                      _buildAchievementBox(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
            ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isBackPressed = true),
      onTapCancel: () => setState(() => _isBackPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          Navigator.pop(context);
          setState(() => _isBackPressed = false);
        }
      },
      child: Image.asset(
        _isBackPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Color(0xFF2374B5)),
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          color: Colors.black.withOpacity(0.4),
          child: CustomTopBar(
            onNotificationTapped: () {
              Navigator.pushNamed(context, '/notification');
            },
            onSettingsTapped: () {
              Navigator.pushNamed(context, '/setting');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBox() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10), 
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(
              'assets/images/design/design2.png',
              height: 180, 
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Image.asset(
              'assets/images/design/design1.png',
              width: 50,
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatarSection(),
                const SizedBox(width: 16),
                _buildUserInfoSection(),
              ],
            ),
          ),
        ], 
      ),
    );
  }

  Widget _buildAvatarSection() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(130, 130),
                painter: GradientCircularProgressPainter(
                  progress: _expPercent,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  strokeWidth: 8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: IgnorePointer(
                    child: Transform.translate(
                      offset: const Offset(2, 20), 
                      child: Transform.scale(
                        scale: 1.6, 
                        child: RepaintBoundary( 
                          child: CharacterWidget(
                            user: _targetUser,
                            isInteractive: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFE0E0E0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$_level", 
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Colors.black,
                      height: 1,
                    ),
                  ),
                  const Text(
                    "Lv.",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                "UID : $_uid", 
                style: const TextStyle(
                  color: Color(0xFF00385D), 
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 5),
              Image.asset(
                'assets/images/icon/iconCopy.png',
                width: 16,
                height: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 🌟 ใช้ _buildInfoField ที่ไม่มีปุ่มแก้ไข
          _buildInfoField(
            content: _displayName,
            columnName: 'user_name',
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
              overflow: TextOverflow.ellipsis,
            ),
            borderColor: const Color(0xFF9DD0E7),
            height: 35,
          ),
          const SizedBox(height: 6),
          _buildInfoField(
            content: _displayBio,
            columnName: 'user_detail',
            textStyle: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              overflow: TextOverflow.ellipsis,
            ),
            borderColor: const Color(0xFF9DD0E7),
            height: 30,
          ),
          const SizedBox(height: 8),
          _buildLinearExpBar(),
        ],
      ),
    );
  }

  // 🌟 ฟังก์ชันแสดงรายละเอียดแบบ Read-only
  void _showViewDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFAAD7EA),
                width: 3,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "รายละเอียด$title",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00385D),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFAAD7EA), width: 2),
                  ),
                  child: Text(
                    content.isEmpty ? "ไม่มีข้อมูล" : content,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2374B5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("ปิด", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🌟 ฟังก์ชัน _buildInfoField ที่มีปุ่มลูกตาดูรายละเอียด
  Widget _buildInfoField({
    required String content,
    required String columnName,
    required TextStyle textStyle,
    required Color borderColor,
    double height = 35,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(content, style: textStyle)),
          GestureDetector(
            onTap: () {
              _showViewDialog(
                columnName == 'user_name' ? 'ชื่อ' : 'แนะนำตัว',
                content,
              );
            },
            child: const Icon(
              Icons.visibility,
              color: Color(0xFF1E5173),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinearExpBar() {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              "EXP",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "$_currentExp/$_nextLevelExp", 
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 16,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  color: const Color(0xFF535353),
                ),
                FractionallySizedBox(
                  widthFactor: _expPercent, 
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox() {
    return Column(
      children: [
        _buildBoxHeader(
          iconPath: 'assets/images/icon/icon-white-loading.png',
          title: "ค่าความสามารถ",
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: _buildBoxDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 160,
                width: 160,
                child: Transform.translate(
                  offset: Offset(0, _targetUser?.bodyType.toUpperCase() == 'KID' ? 20 : 0),
                  child: CharacterWidget(
                    user: _targetUser,
                    isInteractive: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildStatRow('assets/images/profile/stat-int-img.png', "ความฉลาด", _intStat),
                    const SizedBox(height: 8),
                    _buildStatRow('assets/images/profile/stat-str-img.png', "ความแข็งแรง", _strStat),
                    const SizedBox(height: 8),
                    _buildStatRow('assets/images/profile/stat-cre-img.png', "ความคิดสร้างสรรค์", _creStat),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String iconPath, String label, String value) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFF1A3D62), Color(0xFF195290)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(iconPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
             value,
             style: const TextStyle(
               fontWeight: FontWeight.bold,
               fontSize: 14,
               color: Colors.black,
             ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildAchievementBox() {
    return Column(
      children: [
        _buildBoxHeader(
          iconPath: 'assets/images/icon/iconAchievement.png',
          title: "ความสำเร็จ $_unlockedAchievements/$_totalAchievements",
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: _buildBoxDecoration(),
          child: SingleChildScrollView( 
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: _achievementImages.isEmpty 
                ? [
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text("ยังไม่มีความสำเร็จที่ปลดล็อก", style: TextStyle(color: Colors.grey)),
                    )
                  ]
                : _achievementImages.map((imagePath) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _buildAchievementItem(imagePath),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementItem(String imagePath) {
    return Container(
      width: 55,
      height: 55,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9DD0E7), width: 2),
      ),
      child: ClipOval(
        child: imagePath.startsWith('http')
            ? Image.network(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.star, color: Colors.grey),
              )
            : Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.star, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildBoxHeader({required String iconPath, required String title}) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2374B5), Color(0xFF9DD0E7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Row(
          children: [
              Image.asset(
              iconPath,
              height: 50,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Image.asset(
              'assets/images/design/design1.png',
              width: 50,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildBoxDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      border: const Border(
        left: BorderSide(color: Color(0xFF9DD0E7), width: 2),
        right: BorderSide(color: Color(0xFF9DD0E7), width: 2),
        bottom: BorderSide(color: Color(0xFF9DD0E7), width: 2),
      ),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
    );
  }
}

class GradientCircularProgressPainter extends CustomPainter {
  final double progress;
  final Gradient gradient;
  final double strokeWidth;

  GradientCircularProgressPainter({
    required this.progress,
    required this.gradient,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.grey.withValues(alpha: 0.2);
      
    canvas.drawCircle(center, radius, trackPaint);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159 / 4, 
      2 * 3.14159 * progress, 
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}