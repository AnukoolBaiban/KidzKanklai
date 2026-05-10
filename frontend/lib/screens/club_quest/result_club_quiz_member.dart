import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image;
import 'package:flutter_application_1/config/rive_cache.dart';
import 'package:flutter_application_1/screens/result_stat.dart' show AnimatedUpwardArrow;
import 'package:flutter_application_1/widgets/reward_popup.dart';

class ResultExamScreen extends StatefulWidget {
  final User? user;
  final bool isPassed;
  final int score;
  final int total;
  
  // 🌟 1. เปลี่ยนการรับค่า StatusRewards จาก Map ธรรมดา เป็น List ที่มาจาก API
  final List<dynamic>? rewardsList;

  const ResultExamScreen({
    Key? key,
    this.user,
    required this.isPassed,
    required this.score,
    required this.total,
    this.rewardsList, // 🌟 รับ List รางวัล
  }) : super(key: key);

  @override
  State<ResultExamScreen> createState() => _ResultExamScreenState();
}

class _ResultExamScreenState extends State<ResultExamScreen> {
  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMINumber? _faceInput;
  SMINumber? _skinInput;
  SMINumber? _clothInput;
  StateMachineController? _controller;
  bool _isRiveLoaded = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      _fetchUser();
    }
  }

  Future<void> _fetchUser() async {
    final user = await ApiService.getProfile(0);
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
      _syncRiveToEquipped(); // ซิงค์ข้อมูลหลังจากโหลด User เสร็จ
    }
  }

  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );
    if (controller == null && artboard.stateMachines.isNotEmpty) {
      controller = StateMachineController.fromArtboard(
        artboard,
        artboard.stateMachines.first.name,
      );
    }

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;

      for (var input in controller.inputs) {
        if (input.name == 'Pose') _poseInput = input as SMINumber;
        if (input.name == 'HairID') _hairInput = input as SMINumber;
        if (input.name == 'FaceID') _faceInput = input as SMINumber;
        if (input.name == 'SkinID') _skinInput = input as SMINumber;
        if (input.name == 'OutfitID') {
          _clothInput = input as SMINumber;
        }
      }

      _syncRiveToEquipped();

      if (_poseInput != null) {
        _poseInput!.value = widget.isPassed ? 2.0 : 1.0; 
      }
    }
    if (mounted) setState(() => _isRiveLoaded = true);
  }

  double _parseId(String s) {
    if (s.isEmpty) return 0;
    if (s.contains('_')) {
      try {
        return double.parse(s.split('_').last);
      } catch (_) {}
    }
    if (s.contains(' ')) {
      try {
        return double.parse(s.split(' ').last);
      } catch (_) {}
    }
    try {
      return double.parse(s);
    } catch (_) {
      return 0;
    }
  }

  double _getCorrectHairId(double originalId) {
    if (originalId == 2.0) return 3.0; 
    if (originalId == 3.0) return 4.0; 
    if (originalId == 4.0) return 2.0; 
    return originalId;
  }

  void _syncRiveToEquipped() {
    if (_controller == null || _currentUser == null) return;

    try {
      if (_hairInput != null) _hairInput!.value = _getCorrectHairId(_parseId(_currentUser!.equippedHair));
      if (_faceInput != null) _faceInput!.value = _parseId(_currentUser!.equippedFace);
      if (_skinInput != null) _skinInput!.value = _parseId(_currentUser!.equippedSkin);
      if (_clothInput != null) {
        _clothInput!.value = _parseId(_currentUser!.equippedOutfit);
      }
      if (_poseInput != null) {
        _poseInput!.value = widget.isPassed ? 2.0 : 1.0;
      }
    } catch (e) {
      print("Error syncing Rive Profile: $e");
    }
  }

  String _getModelAsset() {
    if (_currentUser != null) {
      final bt = _currentUser!.bodyType.toUpperCase();
      if (bt == 'ADULT') return 'assets/animation/adult.riv';
      if (bt == 'TEEN') return 'assets/animation/teen.riv';
      return 'assets/animation/kid.riv';
    }
    return 'assets/animation/kid.riv';
  }

  double _getTopSpacing() {
    if (_currentUser == null) return 40;
    final bt = _currentUser!.bodyType.toUpperCase();
    if (bt == 'ADULT') return 100;
    if (bt == 'TEEN') return 80;
    return 40;
  }

  double _getCharacterScale() {
    if (_currentUser == null) return 1.5;
    final bt = _currentUser!.bodyType.toUpperCase();
    if (bt == 'ADULT') return 1.4;
    if (bt == 'TEEN') return 1.4;
    return 1.5;
  }

  Offset _getCharacterOffset() {
    if (_currentUser == null) return const Offset(0, 10);
    final bt = _currentUser!.bodyType.toUpperCase();
    if (bt == 'ADULT') return const Offset(0, -35);
    if (bt == 'TEEN') return const Offset(0, -35);
    return const Offset(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 60.0 + topPadding;
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 375).clamp(0.8, 1.2);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              color: widget.isPassed
                  ? const Color(0xFFE2F5FD)
                  : const Color(0xFFE8F5E9),
              child: Image.asset(
                widget.isPassed
                    ? 'assets/images/background/bg11.png'
                    : 'assets/images/background/bg13.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: widget.isPassed
                        ? const Color(0xFFE2F5FD)
                        : const Color(0xFFE8F5E9),
                  );
                },
              ),
            ),
          ),

          // Main Content
          Positioned.fill(
            top: topBarHeight + 80,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * scale,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 กล่องหลัก
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.symmetric(
                        vertical: 30 * scale,
                        horizontal: 20 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: widget.isPassed ? 15 : 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ✅ Success Text + Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                widget.isPassed
                                    ? 'assets/images/icon/check2.png'
                                    : 'assets/images/icon/X.png',
                                height: 40 * scale,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    widget.isPassed
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 40 * scale,
                                    color: widget.isPassed
                                        ? Colors.green
                                        : Colors.red,
                                  );
                                },
                              ),
                              SizedBox(width: 8),
                              Text(
                                widget.isPassed
                                    ? 'คะแนนผ่านเกณฑ์'
                                    : 'คะแนนไม่ผ่านเกณฑ์',
                                style: TextStyle(
                                  fontSize: 24 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 4 * scale),

                          // Score
                          Text(
                            '${widget.score}/${widget.total} คะแนน',
                            style: TextStyle(
                              fontSize: 16 * scale,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          SizedBox(height: _getTopSpacing()), 

                          // ✅ รูปตัวละคร Rive + ลูกศรเด้งขึ้น
                          SizedBox(
                            height: 200,
                            width: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // ตัวละคร Rive
                                _currentUser == null 
                                    ? Image.asset(
                                        widget.isPassed 
                                            ? 'assets/images/profile/profile-character.png'
                                            : 'assets/images/profile/sad-character.png',
                                        height: 250,
                                      )
                                    : Transform.scale(
                                        scale: _getCharacterScale(), 
                                        alignment: Alignment.center,
                                        child: Transform.translate(
                                          offset: _getCharacterOffset(), 
                                          child: (RiveCache().getFile(_getModelAsset()) != null 
                                              ? RiveAnimation.direct(
                                                  RiveCache().getFile(_getModelAsset())!,
                                                  fit: BoxFit.contain,
                                                  onInit: _onRiveInit,
                                                )
                                              : RiveAnimation.asset(
                                                  _getModelAsset(), 
                                                  fit: BoxFit.contain,
                                                  onInit: _onRiveInit,
                                                )),
                                        ),
                                      ),

                              ],
                            ),
                          ),

                          SizedBox(height: 20 * scale),

                          // 🌟 2. แสดงของรางวัลจริงจาก API
                          widget.isPassed
                              ? Column(
                                  children: [
                                    Text(
                                      'รางวัลที่ได้รับ',
                                      style: TextStyle(
                                        fontSize: 20 * scale,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 16 * scale),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: _buildRewardList(scale),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    SizedBox(height: 12 * scale),
                                    Text(
                                      'โปรดตอบคำถามใหม่อีกครั้ง\n(ติดคูลดาวน์ 10 นาที)', // เพิ่มข้อความคูลดาวน์ให้ชัดเจนขึ้น
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16 * scale,
                                        fontWeight: FontWeight.normal,
                                        color: Colors.black54,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ✅ ปุ่มรับรางวัล / ถัดไป / ย้อนกลับ
                    Builder(builder: (context) {
                      final bool hasRewards = widget.isPassed &&
                          widget.rewardsList != null &&
                          widget.rewardsList!.isNotEmpty;

                      // กำหนดสีปุ่ม: เขียว=ผ่าน+มีรางวัล, ฟ้า=ผ่าน+ไม่มีรางวัล, แดง=ไม่ผ่าน
                      final List<Color> gradientColors = hasRewards
                          ? [Color(0xFF85D755), Color(0xFF34C759)]
                          : widget.isPassed
                              ? [Color(0xFF556AEB), Color(0xFF59ABEC)]
                              : [Color(0xFFE94444), Color(0xFFC62828)];

                      // กำหนดข้อความปุ่ม
                      final String buttonLabel = hasRewards
                          ? 'รับรางวัล'
                          : widget.isPassed
                              ? 'ถัดไป'
                              : 'ย้อนกลับ';

                      return Container(
                        width: 180,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            // 🌟 1. ถ้าผ่านภารกิจและมีของรางวัล ให้แสดง RewardPopup ก่อน
                            if (hasRewards) {
                              List<RewardData> popupRewards = [];
                              for (var reward in widget.rewardsList!) {
                                final String name = reward['name'] ?? '';
                                final int amount = reward['amount'] ?? 1;

                                // 🌟 ตรวจสอบ item_id ก่อน (20=Coin, 22=EXP) แล้ว fallback ไปเช็คจาก name
                                final int itemId = reward['item_id'] ?? 0;
                                final String itemType = (reward['item_type'] ?? '').toUpperCase();
                                if (itemId == 22 || itemType == 'EXP' || name.toUpperCase().contains('EXP')) {
                                  popupRewards.add(RewardData.exp(amount));
                                } else if (itemId == 20 || itemType == 'COIN' || itemType == 'CURRENCY' ||
                                    name.toUpperCase().contains('COIN') || name.contains('เหรียญ')) {
                                  popupRewards.add(RewardData.coin(amount));
                                } else {
                                  popupRewards.add(RewardData.item(name: name, amount: amount, image: reward['image']));
                                }
                              }

                              // โชว์ popup รอจนกดปิด
                              await RewardPopup.show(
                                context,
                                rewards: popupRewards,
                              );
                            }

                            // 🌟 2. นำทางตามผลลัพธ์
                            if (context.mounted) {
                              if (widget.isPassed) {
                                // ✅ ผ่าน → ไปหน้าห้องชมรมหลัก
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/club',
                                  (route) => route.isFirst,
                                );
                              } else {
                                // ❌ ไม่ผ่าน → ย้อนกลับไปหน้ารายละเอียดภารกิจ
                                Navigator.pop(context);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            buttonLabel,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Top Bar
          _buildTopBar(topPadding, topBarHeight),

          // Blue Header
          _buildBlueHeader(topBarHeight),
        ],
      ),
    );
  }

  // 🌟 ฟังก์ชันสร้างรายการของรางวัล
  List<Widget> _buildRewardList(double scale) {
    if (widget.rewardsList == null || widget.rewardsList!.isEmpty) {
      return [const Text("ไม่มีรางวัล")];
    }

    List<Widget> rewardWidgets = [];
    for (int i = 0; i < widget.rewardsList!.length; i++) {
      final reward = widget.rewardsList![i];
      final String name = reward['name'] ?? 'Item';
      final int amount = reward['amount'] ?? 1;

      // 🌟 ตรวจสอบ item_id ก่อน (20=Coin, 22=EXP) แล้ว fallback ไปเช็คจาก name
      final int itemId = reward['item_id'] ?? 0;
      final String itemType = (reward['item_type'] ?? '').toUpperCase();
      bool isExp = itemId == 22 || itemType == 'EXP' || name.toUpperCase().contains('EXP');
      bool isCoin = itemId == 20 || itemType == 'COIN' || itemType == 'CURRENCY' ||
          name.toUpperCase().contains('COIN') || name.contains('เหรียญ');
      
      String imagePath = 'assets/images/item/Gasha.png';
      IconData icon = Icons.card_giftcard;
      Color color = Colors.purple;

      if (isExp) {
        imagePath = 'assets/images/item/EXP.png';
        icon = Icons.stars_rounded;
        color = Colors.orange;
      } else if (isCoin) {
        imagePath = 'assets/images/item/coin.png'; // สมมติว่ามีรูปเหรียญ
        icon = Icons.monetization_on;
        color = Colors.yellow;
      }

      rewardWidgets.add(
        _buildRewardItem(imagePath, icon, color, '+$amount', scale),
      );

      // เว้นช่องว่างระหว่างไอเทม
      if (i < widget.rewardsList!.length - 1) {
        rewardWidgets.add(SizedBox(width: 16 * scale));
      }
    }
    return rewardWidgets;
  }

  Widget _buildRewardItem(
    String imagePath,
    IconData fallbackIcon,
    Color fallbackColor,
    String text,
    double scale,
  ) {
    return Container(
      width: 70 * scale,
      height: 70 * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: 40 * scale,
            height: 40 * scale,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(fallbackIcon, size: 36 * scale, color: fallbackColor);
            },
          ),
          SizedBox(height: 4 * scale),
          Text(
            text,
            style: TextStyle(
              fontSize: 12 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Header with Back Button & Title
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            /// Title (อยู่กลางจริง)
            const Center(
              child: Text(
                "ผลลัพธ์",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
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
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        child: CustomTopBar(
          // user: widget.user,
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }
}