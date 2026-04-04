import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // 🌟 นำเข้า Supabase
import '../widgets/custom_top_bar.dart';
import '../api_service.dart';

import '../widgets/confirm_giveup_popup.dart';
import '../widgets/reward_popup.dart';
// 🌟 1. นำเข้าไฟล์ ConfirmCompletePopup
import '../widgets/confirm_complete_popup.dart'; // แก้ไข path ให้ตรงกับที่เก็บไฟล์

class QuestDetailScreen extends StatefulWidget {
  final User? user;
  final int? questId; // 🌟 เพิ่มตัวแปรสำหรับรับ ID ภารกิจ

  const QuestDetailScreen({Key? key, this.user, this.questId}) : super(key: key);

  @override
  State<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends State<QuestDetailScreen> {
  bool _isPressed = false;
  bool _isLoading = true; // 🌟 ตัวแปรเช็คสถานะโหลดข้อมูล

  // 🌟 ตัวแปรสำหรับเก็บข้อมูลที่ดึงมาจาก DB
  String _title = "กำลังโหลด...";
  String _description = "";
  String _startDate = "--/--/--";
  String _endDate = "--/--/--";
  String? _imagePath;
  String _questStatus = ""; // 🌟 1. เพิ่มตัวแปรเก็บสถานะ

  @override
  void initState() {
    super.initState();
    _fetchQuestDetail(); // 🌟 ดึงข้อมูลเมื่อเปิดหน้านี้
  }

  // 🌟 ฟังก์ชันดึงข้อมูลจาก Database
  Future<void> _fetchQuestDetail() async {
    if (widget.questId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      // 🌟 2. เปลี่ยนมาดึงจาก do_quests เพื่อเอา status ของผู้เล่นคนนี้
      final data = await Supabase.instance.client
          .from('do_quests')
          .select('''
            status,
            quests (
              name, detail, start_date, due_date, image
            )
          ''')
          .eq('quest_id', widget.questId as Object)
          .eq('user_id', currentUserId ?? '')
          .single();

      final questData = data['quests'];

      if (mounted) {
        setState(() {
          _questStatus = data['status'] ?? 'in_progress'; // 🌟 เก็บสถานะ
          _title = questData['name'] ?? 'ไม่มีชื่อภารกิจ';
          _description = questData['detail'] ?? 'ไม่มีรายละเอียด';
          _startDate = _formatDate(questData['start_date']);
          _endDate = _formatDate(questData['due_date']);
          _imagePath = questData['image']; 
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching quest detail: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🌟 2. เพิ่มฟังก์ชันสำหรับแสดง Dialog รูปภาพแบบเต็ม
  void _showFullScreenImage(BuildContext context, String path) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9), // พื้นหลังดำเข้มโปร่งแสง
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero, // ให้ขยายเต็มหน้าจอ
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🌟 สามารถบีบซูมรูปได้
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: path.startsWith('http')
                    ? Image.network(path, fit: BoxFit.contain)
                    : Image.asset(path, fit: BoxFit.contain),
              ),
              // ปุ่มปิดสีขาวมุมขวาบน
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 ฟังก์ชันแปลงเวลาเป็นรูปแบบ วว/ดด/ปป (พ.ศ.) พร้อมแปลงเป็น UTC+7
  String _formatDate(String? dateStr) {
    if (dateStr == null) return "--/--/--";
    try {
      DateTime parsedDate = DateTime.parse(dateStr);
      
      // 🌟 แปลงเวลาฐานเป็น UTC ก่อน แล้วบวก 7 ชั่วโมงให้กลายเป็นเวลาไทย
      DateTime dt = parsedDate.toUtc().add(const Duration(hours: 7));
      
      int thaiYear = (dt.year + 543) % 100; // เอาแค่ 2 หลักท้าย เช่น 68
      String dd = dt.day.toString().padLeft(2, '0');
      String mm = dt.month.toString().padLeft(2, '0');
      return "$dd/$mm/$thaiYear";
    } catch (e) {
      return "--/--/--";
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topBarHeight = 75.0 + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          _buildBackground(),

          // Top Bar
          _buildTopBar(topPadding, topBarHeight),

          // Main Content
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + 10,
              left: size.width * 0.05,
              right: size.width * 0.05,
              bottom: bottomPadding + 100, // เว้นที่ให้ปุ่ม
            ),
            child: Column(
              children: [
                // Back Button
                Row(children: [_buildBackButton()]),

                SizedBox(height: 10),

                // Content Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(0xFFAAD7EA), width: 3),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Scrollable Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                          child: _isLoading 
                              ? const Center(child: CircularProgressIndicator()) // แสดงวงกลมโหลด
                              : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Quest Title and Dates
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _title,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF447199),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'สร้าง $_startDate',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          'วันที่สิ้นสุด $_endDate',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),

                                Container(height: 2, color: Color(0xFFB3E5FC)),

                                SizedBox(height: 20),

                                // รูปภาพ Section
                                if (_imagePath != null && _imagePath!.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: Color(0xFF9DD0E7),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title อยู่ในกล่อง
                                        Text(
                                          'รูปภาพ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF002A50),
                                          ),
                                        ),

                                        SizedBox(height: 12),

                                        // Responsive Image
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Center(
                                              child: Container(
                                                width: constraints.maxWidth * 0.6, // responsive
                                                constraints: BoxConstraints(
                                                  maxWidth: 300,
                                                  maxHeight: 300,
                                                ),
                                                child: AspectRatio(
                                                  aspectRatio: 1, // ทำให้รูปเป็นสี่เหลี่ยม
                                                  // 🌟 1. พันด้วย GestureDetector เพื่อให้กดที่รูปได้
                                                  child: GestureDetector(
                                                    onTap: () => _showFullScreenImage(context, _imagePath!), // เรียกฟังก์ชันแสดงรูปเต็ม
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                      // 🌟 ปรับให้รองรับทั้ง Network URL (Cloudinary) และ Asset ปกติ
                                                      child: _imagePath!.startsWith('http')
                                                          ? Image.network(
                                                              _imagePath!,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: _buildImageError,
                                                            )
                                                          : Image.asset(
                                                              _imagePath!,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: _buildImageError,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 20),
                                ],

                                // Description
                                Text(
                                  _description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF313131),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Header "รายละเอียด"
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildHeaderTitle(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Buttons
          _buildBottomButtons(bottomPadding),
        ],
      ),
    );
  }

  // ==================== Components ====================

  Widget _buildImageError(BuildContext context, Object error, StackTrace? stackTrace) {
    return Container(
      color: Color(0xFFE8F4F8),
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 60,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        color: const Color(0xFFE2F5FD),
        alignment: Alignment.center,
        child: Image.asset(
          "assets/images/background/bg-head.png",
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width * 0.8,
          errorBuilder: (context, error, stackTrace) {
            return Container();
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(double topPadding, double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          Navigator.pop(context, true); // 🌟 กลับไปหน้า All Quest (ส่ง true เผื่อให้หน้านั้นรีเฟรชได้ถ้าต้องการ)
        }
      },
      child: Image.asset(
        _isPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: Color(0xFF2374B5)),
          );
        },
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2374B5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            "รายละเอียด",
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

  Widget _buildBottomButtons(double bottomPadding) {
    // 🌟 3. ถ้าสถานะไม่ใช่ in_progress ให้ซ่อนปุ่มไปเลย 
    if (_questStatus != 'in_progress') {
      return const SizedBox.shrink(); // คืนค่าพื้นที่ว่างๆ แทนปุ่ม
    }
    
    return Positioned(
      bottom: bottomPadding + 20,
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: Row(
        children: [
          // ปุ่มยอมแพ้ (สีแดงธรรมดา)
          Expanded(
            child: _buildButton(
              text: 'ยอมแพ้',
              color: Color(0xFFE74A4A),
              useGradient: false,
              onPressed: _openGiveUpPopup,
            ),
          ),

          SizedBox(width: 15),

          // ปุ่มทำสำเร็จ (ไล่สี)
          Expanded(
            child: _buildButton(
              text: 'ทำสำเร็จ',
              color: Color(0xFF4A8FE7),
              useGradient: true,
              onPressed: _openRewardPopup,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    bool useGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: useGradient ? null : color,
        gradient: useGradient
            ? LinearGradient(
                colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
  // ==================== Dialogs ====================

  void _openGiveUpPopup() {
    ConfirmGiveUpPopup.show(
      context,
      onConfirm: () async {
        if (widget.questId == null) return;

        // 1. ปิด Popup ยืนยันก่อน
        Navigator.pop(context); 

        // 2. แสดงวงกลม Loading เพื่อบล็อกหน้าจอระหว่างรอ API
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(child: CircularProgressIndicator());
          },
        );

        // 3. ยิง API ยอมแพ้ภารกิจ
        bool success = await ApiService.cancelQuest(widget.questId!);

        // 4. ปิดวงกลม Loading
        if (mounted) {
          Navigator.pop(context); 
        }

        if (success) {
          if (mounted) {
            // 5.1 ถ้าสำเร็จ แจ้งเตือน และเด้งกลับไปหน้าก่อนหน้า
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('คุณได้ยอมแพ้ภารกิจนี้แล้ว'),
                backgroundColor: Colors.red,
              ),
            );
            // ส่งค่า true กลับไปให้หน้า AllQuestScreen รู้ว่ามีการอัปเดต จะได้รีเฟรชรายการ
            Navigator.pop(context, true); 
          }
        } else {
          // 5.2 ถ้าไม่สำเร็จ หรือเควสหมดเวลา/เสร็จไปแล้ว แจ้งเตือน Error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('เกิดข้อผิดพลาด ไม่สามารถยอมแพ้ภารกิจนี้ได้'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }

  void _openRewardPopup() {
    if (widget.questId == null) return;

    // 🌟 1. เรียกโชว์ Popup ถามเพื่อยืนยันก่อน
    ConfirmCompletePopup.show(
      context,
      onConfirm: () async {
        Navigator.pop(context); // ปิด Popup ยืนยัน

        // แสดง Loading ระหว่างรอ API
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(child: CircularProgressIndicator());
          },
        );

        // 🌟 2. ยิง API (ใช้ completeNormalQuest สำหรับเควสทั่วไป)
        final apiRewards = await ApiService.completeNormalQuest(widget.questId!);

        // ปิด Loading
        if (mounted) {
          Navigator.pop(context);
        }

        // 🌟 3. ถ้า API ทำงานสำเร็จ
        if (apiRewards != null && apiRewards.isNotEmpty && mounted) {
          
          List<RewardData> popupRewards = apiRewards.map<RewardData>((rw) {
            return RewardData(
              type: rw['name'] == 'EXP' ? 'EXP' : 'ITEM',
              amount: rw['added'],
              itemName: rw['name'],
              itemImage: rw['image'], 
            );
          }).toList();

          // 🌟 4. ใช้ await หยุดรอจนกว่าผู้ใช้จะกดปิด Popup รับของรางวัล
          await RewardPopup.show(context, rewards: popupRewards);

          // 🌟 5. เมื่อ Popup รางวัลปิดลงแล้ว ให้เด้งกลับหน้า All Quest พร้อมส่งค่า true ไปรีเฟรช
          if (mounted) {
            Navigator.pop(context, true); 
          }

        } else {
          // ❌ กรณีส่งล้มเหลว
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('เกิดข้อผิดพลาด หรือภารกิจนี้ถูกส่งไปแล้ว'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }
}

// ==================== Model ====================

class Quest {
  final String id;
  final String name;
  final String description;
  final String? imagePath;
  final DateTime startDate;
  final DateTime dueDate;
  final bool isCompleted;

  Quest({
    required this.id,
    required this.name,
    required this.description,
    this.imagePath,
    required this.startDate,
    required this.dueDate,
    this.isCompleted = false,
  });
}