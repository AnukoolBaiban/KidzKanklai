import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_application_1/widgets/music_select_popup.dart';

import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/annotation_instant.dart';
import 'package:flutter_application_1/widgets/ticket_box.dart';
import 'package:flutter_application_1/widgets/confirm_giveup_popup.dart';
import 'package:flutter_application_1/widgets/mission_fail_popup.dart';
import 'package:flutter_application_1/widgets/confirm_exit_popup.dart';
import 'package:flutter_application_1/widgets/confirm_zero_ticket_popup.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/widgets/reward_popup.dart';
import 'package:flutter_application_1/widgets/level_up_popup.dart';
import 'package:flutter_application_1/widgets/character_up_popup.dart';
import 'package:flutter_application_1/widgets/character_widget.dart';
import 'package:flutter_application_1/screens/setting.dart';
import 'package:flutter_application_1/services/audio_manager.dart';
import 'package:flutter_application_1/config/rive_cache.dart';
import 'package:flutter_application_1/screens/loading.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter_application_1/widgets/confirm_start_quest_popup.dart';

class CountdownQuestScreen extends StatefulWidget {
  final User? user;
  const CountdownQuestScreen({super.key, this.user});

  @override
  State<CountdownQuestScreen> createState() => _CountdownQuestScreenState();
}

class _CountdownQuestScreenState extends State<CountdownQuestScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ==========================================
  // State Variables & Controllers
  // ==========================================

  // GlobalKey เพื่อเรียก triggerWin/triggerLose จาก CountdownCharacterWidget
  final GlobalKey<CountdownCharacterWidgetState> _characterKey =
      GlobalKey<CountdownCharacterWidgetState>();

  bool _isPressed = false;
  final TextEditingController _detailController = TextEditingController();
  static const int _maxChars = 15;
  int _charCount = 0;

  bool _isRunning = false;
  bool _isLoadingAPI = false; // 🌟 เพิ่ม: เช็คสถานะตอนยิง API โหลด
  Timer? _timer;
  int _selectedMinutes = 0; // ใน UI คือ "ชั่วโมง"
  int _selectedSeconds = 0; // ใน UI คือ "นาที"
  int _selectedActualSeconds = 0; // วินาที
  int _elapsedTotalSeconds = 0;
  int _totalDurationSeconds = 0; // 🌟 เก็บเวลาทั้งหมดสำหรับเช็ค %

  // 🌟 State สำหรับ Bubble ให้กำลังใจ
  String? _encouragementMessage;
  bool _showEncouragement = false;
  Timer? _encouragementTimer;
  Set<int> _triggeredThresholds = {};

  int? _currentQuestId; // 🌟 เพิ่ม: เก็บ ID ของเควสที่เพิ่งสร้าง
  DateTime? _targetEndTime; // 🌟 เพิ่ม: เก็บเวลาสิ้นสุดที่ Server ตอบกลับมา

  // 👤 User data (โหลดเองเพื่อได้ fashion ล่าสุดเสมอ)
  User? _loadedUser;
  bool _isPageReady = false;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  // 🎵 Music Player
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentTrackPath; // null = ไม่เล่นเพลง

  @override
  void initState() {
    super.initState();
    _initBlinkAnimation();
    _initializePage();
    
    // ตั้งค่าระดับเสียงเริ่มต้นให้ตัวเล่นเพลงของหน้าตาม Setting
    final audioManager = AudioManager();
    _audioPlayer.setVolume(audioManager.isMuted ? 0 : audioManager.musicVolume);

    // ลงทะเบียน lifecycle observer เพื่อจัดการเพลงตอนกด Home / ออกแอป
    WidgetsBinding.instance.addObserver(this);
  }

  /// โหลดข้อมูลที่จำเป็นทั้งหมดก่อนเข้าหน้าจอ
  Future<void> _initializePage() async {
    try {
      // 1. โหลดข้อมูล User พร้อมแฟชั่น
      final user = await ApiService.getProfile(0);
      if (mounted && user != null) {
        setState(() => _loadedUser = user);
      }

      // 2. โหลดโมเดลตัวละครไว้ใน RAM (ใช้ตัวเลือกเดียวกับ LoadingScreen)
      await RiveCache().loadAssets([
        'assets/animation/kid.riv',
        'assets/animation/teen.riv',
        'assets/animation/adult.riv',
      ]);

      if (mounted) {
        setState(() => _isPageReady = true);
      }
    } catch (e) {
      debugPrint("Error initializing page: $e");
      if (mounted) setState(() => _isPageReady = true); // Fallback เข้าไปเลยถ้าพัง
    }
  }

  /// โหลด user พร้อม fashion data ล่าสุดด้วยตัวเอง (เก็บไว้เรียกซ้ำได้ถ้าต้องการรีเฟรช)
  Future<void> _fetchUser() async {
    final user = await ApiService.getProfile(0);
    if (mounted && user != null) {
      setState(() => _loadedUser = user);
    }
  }

  void _initBlinkAnimation() {
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: false);

    _blinkAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.2), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.0), weight: 50),
    ]).animate(_blinkController);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _encouragementTimer?.cancel();
    _blinkController.dispose();
    _detailController.dispose();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─── Lifecycle Handler ────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // กด Home / ออกแอป → หยุดเพลง
        _audioPlayer.stop();
        break;
      case AppLifecycleState.resumed:
        // กลับเข้าแอป → เล่นเพลงต่อถ้าเคยเลือกเพลงไว้
        if (_currentTrackPath != null) {
          final audioManager = AudioManager();
          if (!audioManager.isMuted) {
            _audioPlayer.play(AssetSource(_currentTrackPath!));
          }
        }
        break;
      default:
        break;
    }
  }

  // ==========================================
  // API & Timer Logic
  // ==========================================

  // 🌟 1. ฟังก์ชันเริ่มเควส (ยิง API Start)
  Future<void> _startQuest() async {
    if (_detailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาตั้งชื่อกิจกรรม'), backgroundColor: Colors.red),
      );
      return;
    }

    // คำนวณเวลาทั้งหมดเป็น "นาที" (_selectedMinutes ใน UI ของคุณคือ ชั่วโมง)
    int durationInMinutes = (_selectedMinutes * 60) + _selectedSeconds;
    if (durationInMinutes <= 0) return;

    setState(() => _isLoadingAPI = true);

    // ยิง API
    final result = await ApiService.startInstantQuest(
      name: _detailController.text.trim(),
      durationMinutes: durationInMinutes,
    );

    if (result != null && result['success'] == true) {
      _currentQuestId = result['quest_id'];
      // เริ่มนับเวลาถอยหลังใหม่จากวินาทีนี้เลย เพื่อป้องกันเวลาเดินไประหว่างรอ API หมุน
      _targetEndTime = DateTime.now().add(Duration(
        hours: _selectedMinutes,
        minutes: _selectedSeconds,
        seconds: _selectedActualSeconds, // วินาที
      ));

      _totalDurationSeconds = durationInMinutes * 60 + _selectedActualSeconds;
      _triggeredThresholds.clear();

      setState(() {
        _isRunning = true;
        _isLoadingAPI = false;
        _elapsedTotalSeconds = 0;
      });
      _resumeTimer();
    } else {
      setState(() => _isLoadingAPI = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาด หรือตั๋วไม่พอ'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🌟 2. ฟังก์ชันนับถอยหลัง (อิงจากเวลา Server)
  void _resumeTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _targetEndTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final remaining = _targetEndTime!.difference(now);

      if (remaining.isNegative || remaining.inSeconds <= 0) {
        // 🌟 หมดเวลาแล้ว! ให้เคลียร์เวลา
        _stopTimer(reset: true);
        
        // 🌟 เพิ่มหน่วงเวลา 1 วินาทีก่อนยิง API ให้ชัวร์ว่าฝั่ง Server เวลาเดินไปถึงแล้วจริงๆ
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _completeQuest();
          }
        });
      } else {
        setState(() {
          _elapsedTotalSeconds++;
          _selectedMinutes = remaining.inHours; // ชั่วโมง
          _selectedSeconds = remaining.inMinutes % 60; // นาที
          _selectedActualSeconds = remaining.inSeconds % 60; // วินาที
        });

        // 🌟 ตรวจสอบและแสดงข้อความให้กำลังใจตาม % ความคืบหน้า
        if (_totalDurationSeconds > 0) {
          int elapsed = _totalDurationSeconds - remaining.inSeconds;
          double progress = elapsed / _totalDurationSeconds;
          int progressPercent = (progress * 100).toInt();

          List<int> thresholds = [10, 25, 50, 75, 90];
          for (int t in thresholds) {
            if (progressPercent >= t && !_triggeredThresholds.contains(t)) {
              _triggeredThresholds.add(t);
              _showEncouragementBubble(t);
              break;
            }
          }
        }
      }
    });
  }

  // 🌟 ฟังก์ชันสุ่มและแสดงข้อความให้กำลังใจ
  void _showEncouragementBubble(int percentage) {
    List<String> messages = [];
    switch (percentage) {
      case 10: messages = ["เริ่มต้นได้ดีเลย!", "พยายามเข้านะ!", "ฮึบๆ ลุยเลย!"]; break;
      case 25: messages = ["เก่งมาก!", "สู้ๆ นะ!", "ทำได้ดีมาก!"]; break;
      case 50: messages = ["ครึ่งทางแล้ว!", "ยอดเยี่ยม!", "ไปกันต่อเลย!"]; break;
      case 75: messages = ["ใกล้สำเร็จแล้ว!", "ฮึบๆ อีกนิด!", "อย่ายอมแพ้นะ!"]; break;
      case 90: messages = ["อีกนิดเดียว!", "โค้งสุดท้ายแล้ว!", "เตรียมฉลองเลย!"]; break;
      default: messages = ["สู้ๆ นะ!"];
    }
    
    messages.shuffle();
    
    if (mounted) {
      setState(() {
        _encouragementMessage = messages.first;
        _showEncouragement = true;
      });
      
      _encouragementTimer?.cancel();
      _encouragementTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showEncouragement = false;
          });
        }
      });
    }
  }

  // 🌟 3. ฟังก์ชันจบเควส (ยิง API Complete)
  Future<void> _completeQuest() async {
    if (_currentQuestId == null) return;

    // 🎉 เล่นท่า Win ก่อนยิง API
    _characterKey.currentState?.triggerWin();

    // 🌟 ดึง Profile ก่อนเรียก API เพื่อบันทึก Level เดิม
    final profileBefore = await ApiService.getProfile(0);
    final oldLevel = profileBefore?.level ?? 0;

    setState(() => _isLoadingAPI = true);
    final result = await ApiService.completeInstantQuest(_currentQuestId!);
    setState(() => _isLoadingAPI = false);

    // 🌟 เช็คว่า API ทำงานสำเร็จ (ไม่เป็น null)
    if (result != null && mounted) {
      // 🌟 ดึง Profile ใหม่หลัง API เพื่อเปรียบเทียบ Level
      final freshProfile = await ApiService.getProfile(0);
      final actualNewLevel = freshProfile?.level ?? oldLevel;
      final didLevelUp = actualNewLevel > oldLevel;

      debugPrint('📋 [Countdown] oldLevel=$oldLevel, actualNewLevel=$actualNewLevel, didLevelUp=$didLevelUp');

      final rewards = (result['rewards'] as List?) ?? [];

      // 🌟 เช็คว่ามีของรางวัลให้แจกจริงๆ หรือไม่ (ป้องกันกรณีสร้างตอนตั๋วหมด)
      if (rewards.isNotEmpty) {
        List<RewardData> popupRewards = rewards.map<RewardData>((rw) {
          return RewardData(
            type: rw['name'] == 'EXP' ? 'EXP' : 'ITEM',
            amount: rw['added'],
            itemName: rw['name'],
            itemImage: rw['image'],
          );
        }).toList();

        await RewardPopup.show(
          context, 
          rewards: popupRewards,
          leveledUp: didLevelUp,
          baseLevel: oldLevel,
          newLevel: actualNewLevel,
          user: freshProfile ?? _loadedUser ?? widget.user,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ทำภารกิจสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        
        // 🌟 กรณีไม่มีของรางวัล แต่มีการเลเวลอัพ
        if (mounted && didLevelUp) {
          await RewardPopup.show(
            context, 
            rewards: [],
            leveledUp: true,
            baseLevel: oldLevel,
            newLevel: actualNewLevel,
            user: freshProfile ?? _loadedUser ?? widget.user,
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการส่งภารกิจ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _stopTimer({bool reset = false}) {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      if (reset) {
        _selectedMinutes = 0;
        _selectedSeconds = 0;
        _selectedActualSeconds = 0;
        _elapsedTotalSeconds = 0;
        _totalDurationSeconds = 0;
        _triggeredThresholds.clear();
        _showEncouragement = false;
        _encouragementTimer?.cancel();
      }
    });
  }

  String get _formattedElapsedTime {
    int hours = _elapsedTotalSeconds ~/ 3600;
    int minutes = (_elapsedTotalSeconds % 3600) ~/ 60;
    int seconds = _elapsedTotalSeconds % 60;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}.${minutes.toString().padLeft(2, '0')}.${seconds.toString().padLeft(2, '0')}'
        : '00.${minutes.toString().padLeft(2, '0')}.${seconds.toString().padLeft(2, '0')}';
  }

  // 🌟 4. ฟังก์ชันกดยอมแพ้ (ยิง API Cancel)
  void _handleBackInterrupt() {
    if (_isRunning) {
      ConfirmGiveUpPopup.show(
        context,
        onConfirm: () async {
          Navigator.pop(context); // ปิด Popup ยืนยัน

          // 💔 เล่นท่า Lose ก่อน API
          _characterKey.currentState?.triggerLose();
          
          if (_currentQuestId != null) {
            // ยิง API บอก Backend ว่าขอยอมแพ้
            await ApiService.cancelQuest(_currentQuestId!); 
          }

          String finalTime = _formattedElapsedTime;
          _stopTimer(reset: true);
          
          MissionFailPopup.show(
            context,
            elapsedTime: finalTime,
            onTapContinue: () {
               Navigator.pop(context); // กลับหน้าเดิม
            },
          );
        },
      );
    }
  }

  // ==========================================
  // Main Build Method
  // วาดโครงสร้างหลักของหน้าจอ , จัดการ PopScope สำหรับกดปุ่มย้อนกลับของโทรศัพท์มือถือ
  // ==========================================
  bool _hasUnsavedChanges() {
    bool nameChanged = _detailController.text.trim().isNotEmpty;
    bool timeChanged = _selectedMinutes > 0 || _selectedSeconds > 0 || _selectedActualSeconds > 0;
    return nameChanged || timeChanged;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: !_isPageReady 
        ? const LoadingScreen(isStandalone: false)
        : _buildActualPage(context),
    );
  }

  Widget _buildActualPage(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isSmallScreen = size.width < 380;

    final topBarHeight = 75.0 + topPadding;
    final headerHeight = isSmallScreen ? 70.0 : 80.0;
    final titleFontSize = isSmallScreen ? 28.0 : 36.0;

    return PopScope(
      key: const ValueKey('countdown_quest_main'),
      canPop: !_isRunning && !_hasUnsavedChanges(),
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        
        if (_isRunning) {
          _handleBackInterrupt();
        } else if (_hasUnsavedChanges()) {
          ConfirmExitPopup.show(
            context,
            onConfirm: () {
              Navigator.pop(context); // ปิด Popup ยืนยัน
              Navigator.pop(context); // ออกจากหน้า
            },
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildBackground(),

            // ── ตัวละคร (อยู่หลังโต๊ะ) ──────────────────────────────
            Positioned(
              // ร่างเด็กเล็กกว่า → ลงมาให้เห็นแค่ครึ่งตัวเหนือโต๊ะ
              bottom: (() {
                final bt = (_loadedUser ?? widget.user)
                    ?.bodyType
                    .toUpperCase() ?? '';
                if (bt == 'KID') return bottomPadding + 75.0;
                return bottomPadding + 60.0; // TEEN / ADULT
              })(),
              left: 0,
              right: 0,
              child: Center(
                child: CountdownCharacterWidget(
                  key: _characterKey,
                  user: _loadedUser ?? widget.user,
                  width: size.width * 1.1,
                  height: size.width * 1.1,
                ),
              ),
            ),

            // ── โต๊ะ (อยู่หน้าตัวละคร สร้าง Depth) ─────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/background/Desk.png',
                width: size.width,
                fit: BoxFit.fitWidth,
              ),
            ),

            Column(
              children: [
                _buildTopBar(topPadding),
                _buildBlueHeader(headerHeight, titleFontSize),
                Expanded(
                  child: _buildMainContentScrollable(
                    size,
                    bottomPadding,
                    isSmallScreen,
                  ),
                ),
              ],
            ),

            Positioned(
              bottom: bottomPadding + 50,
              left: 0,
              right: 0,
              child: Center(child: _buildStartButton(size, isSmallScreen)),
            ),

            // ── ปุ่มโน้ตดนตรี (เหนือปุ่มเริ่มทางขวา) ──
            Positioned(
              bottom: bottomPadding + 160,
              right: size.width * 0.08,
              child: _buildMusicButton(),
            ),

            // ── Bubble ข้อความให้กำลังใจ (ด้านซ้ายของตัวละคร) ──
            if (_showEncouragement && _encouragementMessage != null)
              Positioned(
                bottom: bottomPadding + 360.0, // ยกให้สูงขึ้นระดับแก้มของตัวละคร
                left: size.width * 0.04, // ชิดซ้าย
                child: _buildEncouragementBubble(size, isSmallScreen),
              ),

            // ── Overlay โซนกดตัวละครเพื่อให้เล่นท่า Cheerup (ดัก Tap ไว้หน้าสุด) ──
            Positioned(
              bottom: bottomPadding + 140, // อยู่เหนือโต๊ะและปุ่ม
              left: size.width * 0.2, // กะขนาดให้พอดีตัวละครช่วงกลางจอ
              right: size.width * 0.2,
              height: size.width * 0.8, // สูงพอคลุมครึ่งตัวบนของตัวละคร
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _characterKey.currentState?.triggerCheerup();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // UI Component Builders
  // แยกฟังก์ชันสำหรับสร้าง Widget แต่ละส่วน (พื้นหลัง, แถบด้านบน, แถบชื่อภารกิจ, กล่องเวลา, และปุ่มเริ่ม)
  // ==========================================

  Widget _buildEncouragementBubble(Size size, bool isSmallScreen) {
    return AnimatedOpacity(
      opacity: _showEncouragement ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: CustomPaint(
        painter: _SideBubblePainter(),
        child: Container(
          constraints: BoxConstraints(maxWidth: size.width * 0.45),
          padding: const EdgeInsets.fromLTRB(16, 12, 28, 12), // เว้น padding ขวาให้หางข้อความ
          child: Text(
            _encouragementMessage ?? '',
            style: GoogleFonts.kanit(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF333333),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // สร้างพื้นหลังของจอ (ท้องฟ้า)
  Widget _buildBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE2F5FD),
      child: Image.asset("assets/images/background/bg6.png", fit: BoxFit.cover),
    );
  }

  // แถบสีดำบางๆด้านบนสุด แสดงโปรไฟล์ผู้ใช้ เลเวล และเหรียญ
  Widget _buildTopBar(double topPadding) {
    return Container(
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withValues(alpha: 0.4),
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () async {
            // 🌟 เปลี่ยนมาใช้ push แบบ MaterialPageRoute เพื่อแอบส่งค่า hideLogout = true ไปให้หน้า Setting
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingScreen(hideLogout: true),
              ),
            );
            // เมื่อกลับมาจากหน้า Setting ให้อัปเดตระดับเสียงเผื่อผู้ใช้เปลี่ยนค่ามา
            if (!mounted) return;
            final audioManager = AudioManager();
            _audioPlayer.setVolume(audioManager.isMuted ? 0 : audioManager.musicVolume);

            // 🎵 หากมีเพลงที่เลือกเองเล่นอยู่ ให้หยุด BGM หลักอีกรอบ 
            // (ป้องกัน NavigatorObserver สั่งเล่นเพลงประจำหน้าซ้ำตอนกลับมาจาก Setting)
            if (_currentTrackPath != null) {
              audioManager.stopBGM();
            }
          },
        ),
    );
  }

  // กล่องหัวข้อ "ภารกิจทันที" , ปุ่มย้อนกลับ และไอคอนคำถาม (Annotation)
  Widget _buildBlueHeader(
    double height,
    double titleFontSize,
  ) {
    return Container(
        height: height,
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
            Center(
              child: Text(
                "ภารกิจทันที",
                textAlign: TextAlign.center,
                style: GoogleFonts.kanit(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const Positioned(bottom: 8, right: 15, child: AnnotationButton()),
          ],
        ),
    );
  }

  // ปุ่มย้อนกลับ (ลูกศรสีเหลือง) จัดการ Animation การกดและเรียก Popup หากเวลากำลังเดิน
  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        if (_isLoadingAPI) return; // 🌟 กันคนกดย้อนกลับตอน API กำลังหมุน
        
        setState(() => _isPressed = false);
        if (_isRunning) {
          _handleBackInterrupt();
        } else {
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;

          if (!_hasUnsavedChanges()) {
            Navigator.pop(context);
            return;
          }

          ConfirmExitPopup.show(
            context,
            onConfirm: () {
              Navigator.pop(context); // ปิด popup
              Navigator.pop(context); // ปิดหน้าจอสร้างเควสกลับไปหน้าเดิม
            },
          );
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

  // กล่องตั้งค่าเวลา และช่องกรอกข้อความ
  Widget _buildMainContentScrollable(
    Size size,
    double bottomPadding,
    bool isSmallScreen,
  ) {
    final timerFontSize = isSmallScreen ? 48.0 : 64.0;
    final inputFontSize = isSmallScreen ? 16.0 : 18.0;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        bottom: bottomPadding + 140, // เพิ่มพื้นที่สำหรับปุ่มล่างสุด
        left: size.width * 0.05,
        right: size.width * 0.05,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: size.height * 0.5,
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildClickToSetTimeText(),
              const SizedBox(height: 10),
              _buildDigitalTimerCard(timerFontSize),
              const SizedBox(height: 20),
              _buildActivityNameInput(size.width * 0.6, inputFontSize),
            ],
          ),
        ),
      ),
    );
  }

  // ข้อความ "คลิกเพื่อตั้งเวลา" (Effect กระพริบ)
  Widget _buildClickToSetTimeText() {
    return Visibility(
      visible: !_isRunning,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: FadeTransition(
        opacity: _blinkAnimation,
        child: Text(
          "คลิกเพื่อตั้งเวลา",
          style: GoogleFonts.kanit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: const [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4.0,
                color: Colors.black87,
              ),
              Shadow(
                offset: Offset(0, 0),
                blurRadius: 10.0,
                color: Colors.black,
              ),
              Shadow(
                offset: Offset(0, 0),
                blurRadius: 16.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // กล่องขาวแสดงตัวเลขเวลา (หน้าหลัก)
  Widget _buildDigitalTimerCard(double timerFontSize) {
    return GestureDetector(
      onTap: () {
        if (!_isRunning) _showTimePickerPopup(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD9D9D9), width: 4.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "${_selectedMinutes.toString().padLeft(2, '0')}:${_selectedSeconds.toString().padLeft(2, '0')}:${_selectedActualSeconds.toString().padLeft(2, '0')}",
            textAlign: TextAlign.center,
            style: GoogleFonts.kanit(
              fontSize: timerFontSize,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  // ช่องกรอกชื่อกิจกรรม
  Widget _buildActivityNameInput(double width, double fontSize) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 4.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        enabled: !_isRunning,
        controller: _detailController,
        textAlign: TextAlign.center,
        maxLength: _maxChars,
        onChanged: (val) => setState(() => _charCount = val.length),
        style: GoogleFonts.kanit(fontSize: fontSize, color: Colors.black87),
        decoration: InputDecoration(
          hintText: "ตั้งชื่อกิจกรรม",
          hintStyle: GoogleFonts.kanit(
            fontSize: fontSize,
            color: Colors.grey.shade500,
          ),
          border: InputBorder.none,
          isDense: true,
          counterText: '',
          suffix: _charCount > 0
              ? Text(
                  "$_charCount/$_maxChars",
                  style: GoogleFonts.kanit(
                    fontSize: 12,
                    color: _charCount >= _maxChars
                        ? Colors.red.shade400
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // ปุ่มเริ่มจับเวลาถอยหลัง และกล่องไอคอนตั๋วขวาที่ปุ่ม
  // ปุ่มเริ่มจับเวลาถอยหลัง และกล่องไอคอนตั๋วขวาที่ปุ่ม
  Widget _buildStartButton(Size size, bool isSmallScreen) {
    // 🌟 1. เพิ่มการเช็ค _selectedActualSeconds (วินาที) เข้าไปด้วย
    bool isTimeSet = _selectedMinutes > 0 || _selectedSeconds > 0 || _selectedActualSeconds > 0;
    bool isReady = isTimeSet && _detailController.text.trim().isNotEmpty;
    
    final buttonWidth = isSmallScreen ? size.width * 0.70 : size.width * 0.60;
    final buttonHeight = isSmallScreen ? 60.0 : 72.0;
    final buttonFontSize = isSmallScreen ? 28.0 : 36.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () async {
            if (!isReady || _isLoadingAPI) return; // 🌟 ต้องมีชื่อกิจกรรมและเวลาครบถ้วน
            
            if (_isRunning) {
              _handleBackInterrupt();
            } else {
              setState(() {
                _isLoadingAPI = true;
              });

              // ดึงข้อมูลตั๋ว
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              int ticketCount = 0;

              if (user != null) {
                try {
                  final res = await supabase
                      .from('collect')
                      .select('quantity')
                      .eq('user_id', user.id)
                      .eq('item_id', 17)
                      .maybeSingle();
                  if (res != null) {
                    ticketCount = res['quantity'] as int? ?? 0;
                  }
                } catch (e) {
                  debugPrint('Error fetch ticket: $e');
                }
              }

              if (!mounted) return;
              setState(() {
                _isLoadingAPI = false;
              });

              if (ticketCount <= 0) {
                ConfirmZeroTicketPopup.show(
                  context,
                  onConfirm: () {
                    Navigator.pop(context); // ปิด popup
                    _startQuest(); // ให้นับเวลาต่อเพื่อส่งให้ API เช็คเผื่อ Error อีกชั้น
                  },
                );
              } else {
                ConfirmStartQuestPopup.show(
                  context,
                  onConfirm: () {
                    Navigator.pop(context); // ปิด popup
                    _startQuest(); // 🌟 เปลี่ยนจาก _startTimer() เป็น _startQuest()
                  },
                );
              }
            }
          },
          child: Container(
            width: buttonWidth,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _isRunning
                            ? const [Color(0xFFEA4444), Color(0xFF992B2B)] // Red: Give Up
                            : isReady
                            ? const [Color(0xFF59ABEC), Color(0xFF2374B5)] // Blue: Ready
                            : const [Color(0xFFD9D9D9), Color(0xFF8A8A8A)], // Grey: Disabled
                      ),
                    ),
                  ),
                  // 🌟 โชว์ Loading ถ้ากำลังยิง API
                  _isLoadingAPI
                      ? const SizedBox(
                          width: 30, height: 30,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : Text(
                          _isRunning ? "ยอมแพ้" : "เริ่ม",
                          style: GoogleFonts.kanit(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: const [
                              Shadow(offset: Offset(0, 2), blurRadius: 6, color: Colors.black38),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
        if (!_isRunning)
          Positioned(
            top: -15,
            right: -6,
            child: TicketBox(
              slant: 12,
              borderRadius: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/item/Ticket_quest_img.png',
                      width: 30,
                      height: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "-1",
                      style: GoogleFonts.kanit(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ปุ่มโน้ตดนตรีสำหรับเลือกเพลง
  Widget _buildMusicButton() {
    final bool isPlaying = _currentTrackPath != null;
    return GestureDetector(
      onTap: () async {
        final finalSelected = await MusicSelectPopup.show(
          context,
          audioPlayer: _audioPlayer,
          currentTrackPath: _currentTrackPath,
          onSelect: (selected) async {
            // ฟังก์ชันนี้จะถูกเรียกทันทีที่กดเลือกเพลงใน Popup โดยไม่ต้องปิด Popup
            if (!mounted) return;
            setState(() => _currentTrackPath = selected);
            
            // 🎵 หยุดเพลง BGM หลัก
            await AudioManager().stopBGM();

            if (selected == null) {
              await _audioPlayer.stop();
            } else {
              final audioManager = AudioManager();
              await _audioPlayer.setVolume(audioManager.isMuted ? 0 : audioManager.musicVolume);
              await _audioPlayer.play(AssetSource(selected));
              await _audioPlayer.setReleaseMode(ReleaseMode.loop);
            }
          },
        );

        // เมื่อ Popup ปิดลง เราอัปเดตสถานะสุดท้ายอีกครั้ง (เพื่อให้ UI ปุ่มโน้ตซิงค์กับเพลงล่าสุดที่เลือก)
        if (mounted) {
           setState(() => _currentTrackPath = finalSelected);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF59ABEC), Color(0xFF2374B5)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Image.asset(
            'assets/images/button/music-note1.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              isPlaying ? Icons.music_note : Icons.music_off,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  // ฟังก์ชันสั่งเปิด Popup เลือกเวลา (เปิดส่วนของ Time Picker Dialog Sub-Widget)
  void _showTimePickerPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _TimePickerPopupWidget(
            initialHours: _selectedMinutes,
            initialMinutes: _selectedSeconds,
            onConfirm: (int h, int m) {
              setState(() {
                _selectedMinutes = h;
                _selectedSeconds = m;
                _selectedActualSeconds = 0;
              });
            },
          ),
        );
      },
    );
  }
}

// ==========================================
// Time Picker Dialog Sub-Widget
// Widget แสดง Popup เพื่อให้ผู้ใช้ปัดเลือกชั่วโมงและนาทีได้
// ==========================================
class _TimePickerPopupWidget extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;
  final Function(int hours, int minutes) onConfirm;

  const _TimePickerPopupWidget({
    required this.initialHours,
    required this.initialMinutes,
    required this.onConfirm,
  });

  @override
  State<_TimePickerPopupWidget> createState() => _TimePickerPopupWidgetState();
}

class _TimePickerPopupWidgetState extends State<_TimePickerPopupWidget> {
  late int hours;
  late int minutes;

  @override
  void initState() {
    super.initState();
    hours = widget.initialHours;
    minutes = widget.initialMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 380;

    final timeFontSize = isSmallScreen ? 56.0 : 70.0;
    final headerHeight = isSmallScreen ? 100.0 : 120.0;
    final buttonPadding = isSmallScreen ? 30.0 : 40.0;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEDDCC), width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Time Readout
          Container(
            height: headerHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF5F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00",
                  style: GoogleFonts.kanit(
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ),

          // Controls Section
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFC6F4FF), Colors.white],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeSetter(
                      "ชั่วโมง",
                      hours,
                      8,
                      (val) => setState(() => hours = val),
                    ),
                    const SizedBox(width: 20),
                    _buildTimeSetter(
                      "นาที",
                      minutes,
                      59,
                      (val) => setState(() => minutes = val),
                    ),
                  ],
                ),
                SizedBox(
                  height: 44,
                  child: Center(
                    child: Opacity(
                      opacity: _showWarning() ? 1.0 : 0.0,
                      child: Text(
                        _getWarningMessage(),
                        style: GoogleFonts.kanit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFD9534F),
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: _showWarning(),
                  child: GestureDetector(
                    onTap: () {
                      widget.onConfirm(hours, minutes);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: buttonPadding,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: _showWarning()
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFD9D9D9), Color(0xFF8A8A8A)],
                              )
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF2B78BA), Color(0xFF75B2E1)],
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        "ยืนยัน",
                        style: GoogleFonts.kanit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _showWarning() =>
      (hours == 8 && minutes > 0) || (hours == 0 && minutes < 1); // 🌟 แก้จาก < 10 เป็น < 1

  String _getWarningMessage() {
    if (hours == 8 && minutes > 0)
      return '* หมายเหตุ: ตั้งเวลาได้สูงสุด 8 ชั่วโมง';
    if (hours == 0 && minutes < 1) // 🌟 แก้จาก < 10 เป็น < 1
      return '* หมายเหตุ: ตั้งเวลาขั้นต่ำ 1 นาที'; // 🌟 แก้ข้อความแจ้งเตือน
    return '';
  }

  Widget _buildTimeSetter(
    String label,
    int value,
    int maxValue,
    ValueChanged<int> onChanged, {
    int minValue = 0,
  }) {
    final List<int> items = maxValue == 0
        ? [0]
        : List.generate(maxValue - minValue + 1, (i) => minValue + i);
    final initialItem = items.indexOf(value.clamp(minValue, maxValue));

    return Expanded(
      child: Container(
        height: 150,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF9DD0E7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AbsorbPointer(
                  absorbing: maxValue == 0,
                  child: ListWheelScrollView.useDelegate(
                    key: ValueKey('$minValue-$maxValue'),
                    controller: FixedExtentScrollController(
                      initialItem: initialItem < 0 ? 0 : initialItem,
                    ),
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (idx) =>
                        onChanged(items[idx.clamp(0, items.length - 1)]),
                    overAndUnderCenterOpacity: 0.3,
                    childDelegate: maxValue == 0
                        ? ListWheelChildListDelegate(
                            children: [
                              Center(
                                child: Text(
                                  "00",
                                  style: GoogleFonts.kanit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListWheelChildListDelegate(
                            children: items
                                .map(
                                  (v) => Center(
                                    child: Text(
                                      v.toString().padLeft(2, '0'),
                                      style: GoogleFonts.kanit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// Custom Painter สำหรับวาดกล่องข้อความที่มีหางชี้ไปหาตัวละคร
// ==========================================
class _SideBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final bubbleWidth = size.width - 12; // เว้นพื้นที่ 12px ทางขวาให้หาง
    const radius = Radius.circular(16);
    final rect = RRect.fromLTRBR(0, 0, bubbleWidth, size.height, radius);

    final path = Path()..addRRect(rect);
    
    // เติมหางชี้ไปทางขวา (ระดับกลางค่อนไปล่างนิดนึง)
    path.moveTo(bubbleWidth - 1, size.height / 2 - 8);
    path.lineTo(size.width, size.height / 2 + 2); // จุดปลายแหลม
    path.lineTo(bubbleWidth - 1, size.height / 2 + 12);
    path.close();

    // วาดเงาทีเดียวรวมกันทั้งกล่องและหาง
    canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);
    // วาดกล่องข้อความทับ
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
