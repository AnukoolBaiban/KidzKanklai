import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

// 1. นำ GradientCircularProgressPainter จาก profile.dart มาใช้เพื่อให้ดีไซน์หลอดเลือดเหมือนกันเป๊ะ
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

// 2. เปลี่ยนเป็น StatefulWidget เพื่อดึงข้อมูลเองได้
class CustomBottomNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final VoidCallback? onAvatarTapped;

  final VoidCallback? onFashionTapped;
  final VoidCallback? onRoomTapped;
  final VoidCallback? onMapTapped;
  final VoidCallback? onClubTapped;

  final String? avatarUrl;
  // ลบ playerLevel ออกจากพารามิเตอร์ได้เลย เพราะเราจะดึงเองจาก DB แล้ว

  const CustomBottomNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.onAvatarTapped,
    this.onFashionTapped,
    this.onRoomTapped,
    this.onMapTapped,
    this.onClubTapped,
    this.avatarUrl,
  }) : super(key: key);

  @override
  State<CustomBottomNavigationBar> createState() => _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  final _supabase = Supabase.instance.client;

  // State สำหรับเก็บข้อมูลจริง
  int _level = 1;
  double _expPercent = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCharacterData(); // สั่งดึงข้อมูลตอนโหลด UI
  }

  // Logic เดียวกับใน Profile.dart
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
        _expPercent = (requiredExpForNextLevel > 0)
            ? (remainingExp / requiredExpForNextLevel).clamp(0.0, 1.0)
            : 0.0;
      });
    }
  }

  // ดึงแค่ Level และ Experience จาก Character
  Future<void> _fetchCharacterData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final charData = await _supabase
          .from('characters')
          .select('level, experience')
          .eq('user_id', user.id)
          .maybeSingle();

      if (charData != null) {
        final dbLevel = charData['level'] as int? ?? 1;
        final totalExp = charData['experience'] as int? ?? 0;
        
        _updateLevelUI(dbLevel, totalExp); 
      }
    } catch (e) {
      debugPrint('Error fetching character for nav bar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Stack(
        children: [
          // BACKGROUND
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 65,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),

          //STAR DECOR PICTURE
          Positioned(
            left: 0,
            bottom: 0,
            child: Image.asset("assets/images/design/design-left.png"),
          ),

          Positioned(
            right: 0,
            bottom: 0,
            child: Image.asset("assets/images/design/design-right.png"),
          ),

          // Content button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(left: 8, right: 12, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Avatar ใหญ่ขึ้น
                  _buildAvatar(),

                  SizedBox(width: 8),

                  // Navigation Items
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(
                            index: 0,
                            imagePath: "assets/images/icon/icon-fashion.png",
                            label: 'แฟชั่น',
                            onTap: widget.onFashionTapped,
                          ),
                          _buildNavItem(
                            index: 1,
                            imagePath: "assets/images/icon/icon-room.png",
                            label: 'ห้องรับรอง',
                            onTap: widget.onRoomTapped,
                          ),
                          _buildNavItem(
                            index: 2,
                            imagePath: "assets/images/icon/icon-map.png",
                            label: 'แผนที่',
                            onTap: widget.onMapTapped,
                          ),
                          _buildNavItem(
                            index: 3,
                            imagePath: "assets/images/icon/icon-club.png",
                            label: 'ชมรม',
                            onTap: widget.onClubTapped,
                          ),
                        ],
                      ),
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

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () {
        if (widget.onAvatarTapped != null) {
          widget.onAvatarTapped!();
        }
      },
      child: Container(
        width: 85,
        padding: EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 3. วงเลเวลใช้ Progress แบบรุ้ง (ดึงค่า _expPercent จริงมาแสดง)
                  CustomPaint(
                    size: Size(85, 85),
                    painter: GradientCircularProgressPainter(
                      progress: _expPercent,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF88FF40), Color(0xFF66E0FF)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      strokeWidth: 5,
                    ),
                  ),

                  // รูป Avatar
                  Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200, width: 3),
                    ),
                    child: ClipOval(
                      child: widget.avatarUrl != null
                          ? Image.network(
                              widget.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/images/profile/profile_img.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultAvatar();
                                  },
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/profile/profile_img.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar();
                              },
                            ),
                    ),
                  ),

                  // Level Badge (ล่างขวา) - แสดง Level จริง
                  Positioned(
                    left: 55,
                    right: 0,
                    bottom: 6,
                    child: Container(
                      width: 35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Color(0xFFE4E4E4),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_level', // ดึงค่า _level จาก Supabase มาแสดง
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF313131),
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'Lv.',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF313131),
                              height: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF87CEEB), Color(0xFF4A90E2)],
        ),
      ),
      child: Icon(Icons.person, color: Colors.white, size: 40),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String imagePath,
    required String label,
    VoidCallback? onTap,
  }) {
    final isSelected = widget.selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onItemTapped(index);
            if (onTap != null) {
              onTap();
            }
          },
          borderRadius: BorderRadius.circular(360),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: EdgeInsets.all(isSelected ? 4 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [Color(0xFF75C6EA), Color(0xFFCEFFB2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: !isSelected ? Colors.white.withValues(alpha: 0.8) : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Color(0xFF000000).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset(
                        imagePath,
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported,
                            color: isSelected
                                ? Color(0xFF8B4513)
                                : Color(0xFF8B4513).withValues(alpha: 0.5),
                            size: 28,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: Color(0xFF000000),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}