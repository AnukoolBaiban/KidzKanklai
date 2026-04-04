import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/screens/lobby.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/screens/quest_detail.dart';
import 'package:flutter_application_1/widgets/annotation.dart';
import 'package:flutter_application_1/widgets/tutorial_quest.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide User; // 🌟 เพิ่ม Supabase
import 'package:flutter_application_1/widgets/reward_popup.dart';

class AllQuestScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final User? user;

  const AllQuestScreen({super.key, this.initialData, this.user});

  @override
  State<AllQuestScreen> createState() => _AllQuestScreenState();
}

class _AllQuestScreenState extends State<AllQuestScreen> {
  // --- ตัวแปร State ---
  bool _isPressed = false;
  int _selectedTabIndex = 0;
  final List<String> _tabs = ["ทั้งหมด", "ระบบ", "ส่วนตัว", "ประวัติ"];

  // 🌟 ลบ Mock Data ออก และสร้างตัวแปรรับข้อมูลจริงจาก DB
  List<Map<String, dynamic>> _allQuests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 🌟 ดึงข้อมูลทันทีเมื่อเข้าหน้านี้
    _fetchQuestsFromDB();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => const TutorialQuestPopup(),
      );
    });
  }

  // 🌟 ฟังก์ชันดึงข้อมูลจาก Supabase (รองรับของรางวัลไม่อั้น)
  Future<void> _fetchQuestsFromDB() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // 🌟 แอบเรียก API ให้สร้างเควสระบบ (ถ้ายังไม่มี) ก่อนที่จะดึงข้อมูลมาแสดงผล
      await ApiService.initSystemQuests();

      final response = await Supabase.instance.client
          .from('do_quests')
          .select('''
            status, 
            completed_date,
            progress, 
            quests (
              id, 
              name,
              detail,
              type,
              start_date,
              due_date, 
              image,
              target_amount, 
              receive (
                quantity,
                items (
                  name,
                  image
                )
              )
            )
          ''')
          .eq('user_id', currentUserId);

      List<Map<String, dynamic>> loadedQuests = [];
      final now = DateTime.now();

      for (var row in response) {
        final questData = row['quests'];
        if (questData == null) continue;

        String status = row['status'] ?? 'in_progress';
        bool isClaimed = (status == 'completed');

        // 🌟 ดึงค่าความคืบหน้า (Progress) และเป้าหมาย (Target) จาก DB
        int dbProgress = row['progress'] ?? 0;
        int targetAmount = questData['target_amount'] ?? 1;

        // ถ้าเควสสำเร็จ/รับของไปแล้ว ให้ดันหลอดให้เต็ม 100% เลย
        if (isClaimed) {
          dbProgress = targetAmount;
        }

        DateTime? completedDate;
        if (row['completed_date'] != null) {
          completedDate = DateTime.parse(row['completed_date']);
        }

        DateTime dueDate = DateTime.parse(questData['due_date']);
        Duration diff = dueDate.difference(now);

        // 🌟 เพิ่มตัวแปรเช็คว่า "หมดเวลาหรือยัง" โดยดูว่า diff ติดลบไหม
        bool isExpired = diff.isNegative;

        int daysLeft = diff.inDays;
        int hoursLeft = diff.inHours;

        if (daysLeft < 0) daysLeft = 0;
        if (hoursLeft < 0) hoursLeft = 0;

        String type = questData['type'] ?? 'ทั่วไป';
        bool isSystem = (type == 'ระบบ'); // เควสระบบสืบสายดั้งเดิม
        bool isRecommended = (type == 'แนะนำ'); // ภารกิจแนะนำ (type='แนะนำ')
        bool isSystemOrRecommended = isSystem || isRecommended; // ใช้สำหรับ logic UI
        String category = isSystemOrRecommended ? 'ระบบ' : 'ส่วนตัว'; // 'แนะนำ' จัดอยู่ใน tab 'ระบบ'

        // --------------------------------------------------------
        // 🌟 สร้าง List เก็บของรางวัลทั้งหมดที่ดึงมาจาก DB
        // --------------------------------------------------------
        List<Map<String, dynamic>> rewardsList = [];

        if (questData['receive'] != null &&
            (questData['receive'] as List).isNotEmpty) {
          final receiveList = questData['receive'] as List;

          for (var r in receiveList) {
            final int qty = r['quantity'] ?? 0;
            final itemInfo = r['items'];

            if (itemInfo != null) {
              final String itemName = (itemInfo['name'] ?? '').toString();
              final String imgPath =
                  itemInfo['image'] ?? "assets/images/item/default_item.png";

              // เช็คว่าไอเทมนี้ใช่ EXP หรือไม่
              final bool isExp = itemName.toUpperCase() == 'EXP';

              rewardsList.add({
                "name": itemName,
                "amount": qty,
                "image": imgPath,
                "isExp": isExp, // ระบุว่าเป็น EXP เพื่อโชว์เครื่องหมาย +
              });
            }
          }
        }

        DateTime? startDate;
        if (questData['start_date'] != null) {
          startDate = DateTime.tryParse(questData['start_date']);
        }

        loadedQuests.add({
          "id": questData['id'],
          "title": questData['name'] ?? 'ไม่มีชื่อ',
          "description": questData['detail'] ?? 'ไม่มีรายละเอียด',
          "type": type,
          "category": category,
          "rewards": rewardsList,
          "daysLeft": daysLeft,
          "hoursLeft": hoursLeft,
          "isSystem": isSystemOrRecommended, // ใช้เป็น true ทั้งเควสระบบและเควสแนะนำ
          "isRecommended": isRecommended, // บอกว่าเป็นภารกิจแนะนำโดยเฉพาะ
          "progress": dbProgress,
          "totalReq": targetAmount,
          "status": status,
          "isClaimed": isClaimed,
          "isExpired": isExpired,
          "completedDate": completedDate,
          "startDate": startDate ?? DateTime.now(), // 🌟 เผื่อเคสที่ไม่มี start_date
        });
      }

      if (mounted) {
        setState(() {
          _allQuests = loadedQuests;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching quests: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Main Screen ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final topBarHeight = 75.0 + topPadding;
    final headerHeight = 80.0;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),

          // Main Content
          Padding(
            padding: EdgeInsets.only(
              top: topBarHeight + headerHeight + 10,
              bottom: 110 + bottomPadding,
              left: size.width * 0.05,
              right: size.width * 0.05,
            ),
            child: Column(
              children: [
                _buildTabs(),
                const SizedBox(height: 4),
                Expanded(child: _buildQuestContent()),
              ],
            ),
          ),

          _buildTopBar(topPadding, topBarHeight),
          _buildBlueHeader(topBarHeight),
          _buildBottomNavBar(),
        ],
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

  Widget _buildBlueHeader(double topOffset) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF015496), Color(0xFF2273B4)],
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: _buildBackButton(),
              ),
            ),
            const Center(
              child: Text(
                "ภารกิจ",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Positioned(bottom: 8, right: 15, child: AnnotationButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LobbyScreen(user: widget.user)),
          ).then((_) => setState(() => _isPressed = false));
        }
      },
      child: Image.asset(
        _isPressed
            ? 'assets/images/button/bt-hover-Back.png'
            : 'assets/images/button/bt-Back.png',
        width: 50,
        height: 50,
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: CustomBottomNavigationBar(
          selectedIndex: -1,
          avatarUrl: null,
          onItemTapped: (index) {},
          onAvatarTapped: () =>
              Navigator.pushReplacementNamed(context, '/profile'),
          onFashionTapped: () =>
              Navigator.pushReplacementNamed(context, '/fashion'),
          onRoomTapped: () => Navigator.pushReplacementNamed(context, '/lobby'),
          onMapTapped: () => Navigator.pushReplacementNamed(context, '/map'),
          onClubTapped: () => Navigator.pushReplacementNamed(context, '/club'),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        for (int i = 0; i < _tabs.length; i++)
          Expanded(child: _buildTabItem(i)),
        const SizedBox(width: 8),
        Builder(
          builder: (ctx) =>
              _CreateQuestButton(onTap: () => _showCreateQuestPopup(ctx)),
        ),
      ],
    );
  }

  Widget _buildTabItem(int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF002A50) : const Color(0xFF2374B5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _tabs[index],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateQuestPopup(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      useSafeArea: false,
      builder: (BuildContext dialogContext) {
        return Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: _CreateQuestButton(
                onTap: () => Navigator.pop(dialogContext),
              ),
            ),
            Positioned(
              top: offset.dy + renderBox.size.height + 15,
              right: MediaQuery.of(context).size.width * 0.05,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.45,
                  constraints: const BoxConstraints(
                    minWidth: 150,
                    maxWidth: 200,
                  ),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPopupButton("ภารกิจทั่วไป", () {
                        Navigator.pop(dialogContext);
                        // เมื่อกลับมาจากการสร้างเควส ให้ Refresh ดึงข้อมูลใหม่ด้วย
                        Navigator.pushNamed(context, '/createnormalquest').then(
                          (_) {
                            _fetchQuestsFromDB();
                          },
                        );
                      }),
                      const SizedBox(height: 6),
                      _buildPopupButton("ภารกิจทันที", () {
                        Navigator.pop(dialogContext);

                        Navigator.pushNamed(context, '/countdown').then((_) {
                          _fetchQuestsFromDB();
                        });
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopupButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: GoogleFonts.kanit(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // --- 🌟 Logic การกรองข้อมูลตาม Tab แบบใหม่ ---
  Widget _buildQuestContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Map<String, dynamic>> filteredQuests = [];
    final threeMonthsAgo = DateTime.now().subtract(
      const Duration(days: 90),
    ); // ย้อนหลัง 3 เดือน

    // กรองข้อมูลตาม Tab ที่เลือก
    if (_selectedTabIndex == 0) {
      // 🌟 "ทั้งหมด" = โชว์เควสที่กำลังทำอยู่ (ทุกหมวด) + รวมเควสระบบ/แนะนำที่สำเร็จแล้วด้วย
      filteredQuests = _allQuests.where((q) {
        bool isDoing = q['status'] == 'in_progress';
        bool isSystemDone =
            (q['category'] == 'ระบบ') && q['status'] == 'completed';

        return isDoing || isSystemDone; // เอาทั้งคู่มาแสดงผล
      }).toList();
    } else if (_selectedTabIndex == 1) {
      // 🌟 "ระบบ" = แสดงเควสหมวดระบบ และ เควสแนะนำ (ทั้งที่กำลังทำและสำเร็จแล้ว)
      filteredQuests = _allQuests
          .where((q) =>
              q['category'] == 'ระบบ' || // เควสระบบ (type='ระบบ')
              (q['isRecommended'] == true)) // เควสแนะนำ (type='แนะนำ')
          .toList();
    } else if (_selectedTabIndex == 2) {
      // "ส่วนตัว" = หมวดส่วนตัว เฉพาะที่กำลังทำอยู่
      filteredQuests = _allQuests
          .where(
            (q) => q['category'] == 'ส่วนตัว' && q['status'] == 'in_progress',
          )
          .toList();
    } else if (_selectedTabIndex == 3) {
      // 🌟 "ประวัติ" = ทำสำเร็จแล้ว หรือ หมดเวลา (และต้องไม่ใช่หมวดระบบ) ไม่เกิน 3 เดือน
      filteredQuests = _allQuests.where((q) {
        // เช็คสถานะ และเพิ่มเงื่อนไขไม่เอาเควส 'ระบบ' เข้ามาโชว์ในนี้
        bool isDoneOrFailed =
            (q['status'] == 'completed' || q['status'] == 'failed') &&
            q['category'] != 'ระบบ';

        if (isDoneOrFailed) {
          if (q['completedDate'] != null) {
            DateTime compDate = q['completedDate'];
            return compDate.isAfter(threeMonthsAgo);
          }
          return true;
        }
        return false;
      }).toList();
    }

    // --- 🌟 เรียงลำดับตามความสำคัญ ---
    /*
      1. ภารกิจแนะนำ (อยู่บนสุด)
      2. ภารกิจส่วนตัว (เรียงตามที่สร้างมาใหม่สุด startDate descending)
      3. ภารกิจระบบ (อยู่เกือบสุด)
      4. ภารกิจระบบที่สำเร็จแล้ว (อยู่ล่างสุด)
    */
    filteredQuests.sort((a, b) {
      int getRank(Map<String, dynamic> q) {
        bool isRec = q['isRecommended'] == true;
        bool isSys = q['category'] == 'ระบบ';
        bool isCmp = q['status'] == 'completed';

        if (isRec) return 1; // แนะนำ
        if (q['category'] == 'ส่วนตัว') return 2; // ส่วนตัว
        if (isSys && !isCmp) return 3; // ระบบที่ยังไม่เสร็จ
        if (isSys && isCmp) return 4; // ระบบที่เสร็จแล้ว
        return 5;
      }

      int aRank = getRank(a);
      int bRank = getRank(b);

      if (aRank != bRank) {
        return aRank.compareTo(bRank);
      }

      // 🌟 ถ้าอยู่กลุ่มเดียวกัน (เช่นส่วนตัวเหมือนกัน) ให้เรียงตามเวลาที่สร้าง (ใหม่สุดอยู่บน)
      DateTime aDate = a['startDate'] ?? DateTime.now();
      DateTime bDate = b['startDate'] ?? DateTime.now();
      return bDate.compareTo(aDate); // Descending
    });

    if (filteredQuests.isEmpty) {
      return Center(
        child: Text(
          "ไม่มีรายการภารกิจในขณะนี้",
          style: GoogleFonts.kanit(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: filteredQuests.length,
      itemBuilder: (context, index) {
        return QuestCard(
          quest: filteredQuests[index],
          onClaim: () async {
            // โชว์ Loading แบบเดียวกับหน้า Detail
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return const Center(child: CircularProgressIndicator());
              },
            );

            // ยิง API
            final rewards = await ApiService.completeSystemQuest(
              filteredQuests[index]['id'],
            );

            if (mounted) Navigator.pop(context); // ปิด Loading

            if (rewards != null && mounted) {
              // 🌟 แปลงของรางวัลและโชว์ Popup ได้เลย (แบบเดียวกับเควสปกติ)
              List<RewardData> popupRewards = rewards.map<RewardData>((rw) {
                return RewardData(
                  type: rw['name'] == 'EXP' ? 'EXP' : 'ITEM',
                  amount: rw['added'],
                  itemName: rw['name'],
                  itemImage: rw['image'],
                );
              }).toList();

              await RewardPopup.show(context, rewards: popupRewards);

              // รีเฟรชหน้า AllQuestScreen เพื่ออัปเดตสถานะ
              _fetchQuestsFromDB();
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('เกิดข้อผิดพลาด หรือรับรางวัลไปแล้ว'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          onViewDetails: () async {
            final shouldRefresh = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuestDetailScreen(
                  questId: filteredQuests[index]['id'],
                ),
              ),
            );
            
            // 🌟 ถ้ารับค่าเป็น true ให้รีเฟรชหน้าเพื่ออัปเดตข้อมูล
            if (shouldRefresh == true) {
              _fetchQuestsFromDB();
            }
          },
        );
      },
    );
  }
}

class _CreateQuestButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateQuestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF68E2FA), Color(0xFF2374B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Center(
            child: Image.asset(
              "assets/images/button/bt-create.png",
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class QuestCard extends StatelessWidget {
  final Map<String, dynamic> quest;
  final VoidCallback onClaim;
  final VoidCallback onViewDetails;

  const QuestCard({
    super.key,
    required this.quest,
    required this.onClaim,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    bool isSystem = quest['category'] == 'ระบบ';
    bool isRecommended = quest['isRecommended'] ?? false;
    bool isClaimed = quest['isClaimed'] ?? false;
    int progress = quest['progress'] ?? 0;
    int totalReq = quest['totalReq'] ?? 1;
    bool isComplete = progress >= totalReq;

    // 🌟 เควสแนะนำ = สีทอง/ส้ม, เควสระบบ = สีเขียว, ส่วนตัว = สีฟ้า
    List<Color> badgeColors = isRecommended
        ? [
            const Color(0xFFFF8C00),
            const Color(0xFFFFD27F),
          ] // สีส้ม สำหรับเควสแนะนำ
        : isSystem
        ? [const Color(0xFF6CC732), const Color(0xFFCEFFB2)]
        : [const Color(0xFF59ABEC), const Color(0xFFC6F4FF)];

    // 🌟 1. ดึงสถานะ Failed ออกมาเช็ค
    bool isFailed = quest['status'] == 'failed' || quest['isExpired'] == true;

    // 🌟 2. เปลี่ยนเงื่อนไขการใส่สีพื้นหลังและขอบ
    Decoration backgroundDecoration = BoxDecoration(
      color:
          (isClaimed || isFailed) // ถ้าสำเร็จแล้ว หรือ ยอมแพ้แล้ว ให้เป็นสีเทา
          ? Colors.grey.shade300.withOpacity(0.85)
          : Colors.white.withOpacity(0.8),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: (isClaimed || isFailed) ? Colors.grey : const Color(0xFF9DD0E7),
        width: 2,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: backgroundDecoration,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: badgeColors,
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isRecommended
                                  ? 'แนะนำ'
                                  : isSystem
                                  ? 'ระบบ'
                                  : quest['type'],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isRecommended
                                    ? const Color.fromARGB(255, 0, 0, 0)
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            quest['title'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      // 🌟 เปลี่ยนมาใช้การวนลูปสร้าง RewardBadge ตามจำนวนของรางวัลจริงๆ ใน List
                      children: (quest['rewards'] as List<dynamic>? ?? [])
                          .map<Widget>((reward) {
                            bool isExp = reward['isExp'] ?? false;

                            return RewardBadge(
                              label: isExp ? "EXP" : "Item",
                              // ถ้าเป็น EXP โชว์เครื่องหมาย +, ถ้าเป็นของทั่วไปโชว์ตัว x
                              value: isExp
                                  ? "+${reward['amount']}"
                                  : "x${reward['amount']}",
                              color: isExp
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              iconPath: reward['image'],
                              isClaimed: isClaimed,
                            );
                          })
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              width: 1,
              // 🌟 เช็ค isFailed ด้วย เพื่อให้เส้นกั้นเป็นสีเทาเหมือนกัน
              color: (isClaimed || isFailed)
                  ? Colors.grey
                  : const Color(0xFF9DD0E7),
            ),

            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🌟 1. เช็คว่าเป็นเควสประวัติ (ทำเสร็จแล้วหรือเฟล) และเป็นเควสประเภท "ทันที" หรือไม่
                    if ((isClaimed || isFailed) &&
                        quest['type'] == 'ทันที') ...[
                      // โชว์ข้อความ "สำเร็จ" หรือ "ไม่สำเร็จ" ตัวใหญ่ตรงกลางแทนปุ่ม
                      Text(
                        isClaimed ? "สำเร็จ" : "ไม่สำเร็จ",
                        style: TextStyle(
                          color: isClaimed
                              ? const Color(0xFF34C759)
                              : const Color(0xFFE74A4A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ดึงข้อมูล string จาก description มาคำนวณชั่วโมงและนาที
                      Text(
                        (() {
                          if (quest['description'] != null &&
                              quest['description'].contains(
                                "กิจกรรมจับเวลา:",
                              )) {
                            final match = RegExp(
                              r'\d+',
                            ).firstMatch(quest['description']);
                            if (match != null) {
                              int totalMinutes = int.parse(match.group(0)!);
                              if (totalMinutes >= 60) {
                                int h = totalMinutes ~/ 60;
                                int m = totalMinutes % 60;
                                return m > 0
                                    ? "เวลาที่ตั้ง: $h ชั่วโมง $m นาที"
                                    : "เวลาที่ตั้ง: $h ชั่วโมง";
                              } else {
                                return "เวลาที่ตั้ง: $totalMinutes นาที";
                              }
                            }
                          }
                          return "เวลาที่ตั้ง: ${quest['daysLeft'] > 0 ? '${quest['daysLeft']} วัน ' : ''}${quest['hoursLeft']} ชม.";
                        })(),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ]
                    // 🌟 2. เพิ่มเงื่อนไขสำหรับ "เควสระบบที่อยู่ในประวัติ (ทำสำเร็จแล้ว)"
                    else if (isClaimed && isSystem) ...[
                      // โชว์แค่คำว่า "สำเร็จ" ใหญ่ๆ ตรงกลาง ซ่อนปุ่มและหลอด
                      const Text(
                        "สำเร็จ",
                        style: TextStyle(
                          color: Color(0xFF34C759), // สีเขียว
                          fontSize: 16, // ปรับให้ใหญ่ขึ้นนิดนึงให้ดูเต็มพื้นที่
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]
                    // 🌟 3. ถ้าเป็นเควสปกติ หรือเควสระบบที่ "กำลังทำอยู่" ให้โชว์ปุ่มและหลอดตามปกติ
                    else ...[
                      if (isClaimed)
                        _buildActionButton(
                          text: 'รายละเอียด',
                          onPressed: onViewDetails,
                          bgColor: const Color(0xFF536DFE),
                        )
                      else if (isSystem && isComplete)
                        _buildActionButton(
                          text: 'รับรางวัล',
                          onPressed: onClaim,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF85D755), Color(0xFF34C759)],
                          ),
                        )
                      else
                        _buildActionButton(
                          text: isSystem ? 'รับรางวัล' : 'รายละเอียด',
                          onPressed: isSystem ? null : onViewDetails,
                          bgColor: isSystem
                              ? Colors.grey
                              : const Color(0xFF536DFE),
                        ),

                      const SizedBox(height: 12),

                      // หลอดความคืบหน้า (ซ่อนถ้าเป็นเควสระบบที่เคลมแล้ว แต่โค้ดเราดักไว้ข้างบนแล้ว)
                      if (isSystem) ...[
                        _buildProgressBar(
                          isClaimed || isComplete,
                          progress,
                          totalReq,
                        ),
                        const SizedBox(height: 4),
                      ],

                      // โชว์เวลาด้านล่างปุ่มแบบเดิม
                      if (isClaimed)
                        const Text(
                          "สำเร็จ",
                          style: TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (isFailed)
                        const Text(
                          "ไม่สำเร็จ",
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 0, 0),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (quest['daysLeft'] != null &&
                          quest['daysLeft'] < 3)
                        Text(
                          quest['daysLeft'] < 1
                              ? (quest['hoursLeft'] <= 0
                                    ? "เหลือน้อยกว่า 1 ชั่วโมง"
                                    : "เหลืออีก ${quest['hoursLeft']} ชั่วโมง")
                              : "เหลืออีก ${quest['daysLeft']} วัน",
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    Color? bgColor,
    Gradient? gradient,
  }) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: gradient == null
          ? (bgColor ?? Colors.grey)
          : Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.grey,
      disabledForegroundColor: Colors.white,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      minimumSize: const Size(double.infinity, 36),
      elevation: 0,
    );
    Widget btn = ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
    if (gradient != null) {
      btn = Container(
        width: double.infinity,
        height: 36,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: btn,
      );
    }
    return btn;
  }

  Widget _buildProgressBar(bool isDone, int progress, int totalReq) {
    // 🌟 คำนวณเปอร์เซ็นต์ (หารกันแล้วล็อกค่าไว้ไม่ให้เกิน 1.0 หรือ 100%)
    double percent = totalReq > 0 ? (progress / totalReq).clamp(0.0, 1.0) : 0.0;
    if (isDone) percent = 1.0; // ถ้าสำเร็จแล้ว บังคับเต็ม 100%

    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: Colors.grey.shade300, // สีเทาพื้นหลัง (ส่วนที่ยังไม่เต็ม)
        borderRadius: BorderRadius.circular(10),
      ),
      // ใช้ Stack เพื่อเอาหลอดสีไปวางซ้อนทับบนสีเทา และเอาตัวหนังสือวางทับอีกที
      child: Stack(
        children: [
          // 🌟 1. แถบสีที่จะความกว้างเพิ่มขึ้นตาม percent
          FractionallySizedBox(
            alignment: Alignment.centerLeft, // เริ่มเติมสีจากซ้ายไปขวา
            widthFactor: percent, // ความกว้าง (0.0 ถึง 1.0)
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF59ABEC), Color(0xFF85D755)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // 🌟 2. ตัวอักษรบอกจำนวน
          Center(
            child: Text(
              isDone ? "$totalReq/$totalReq" : "$progress/$totalReq",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                // เปลี่ยนสีตัวหนังสือเป็นขาวถ้าหลอดสีวิ่งมาเกินครึ่งทางแล้ว จะได้อ่านง่าย
                color: percent > 0.5 ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RewardBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? iconPath;
  final bool isClaimed;

  const RewardBadge({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.iconPath,
    this.isClaimed = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Center(
                child: iconPath != null
                    ? Image.asset(iconPath!, width: 36, height: 36)
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF81D4FA), Color(0xFF81C784)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "EXP",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black26,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );

    if (isClaimed) {
      badge = Stack(
        alignment: Alignment.center,
        children: [
          badge,
          Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      );
    }

    return badge;
  }
}
