import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/lobby.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/services/audio_manager.dart';
import 'package:flutter_application_1/api_service.dart' as api;

import 'package:flutter_application_1/widgets/custom_top_bar.dart';

class SettingScreen extends StatefulWidget {
  final api.User? user;
  final bool hideLogout; // 🌟 เพิ่มตัวแปรนี้
  const SettingScreen({super.key, this.user, this.hideLogout = false}); // 🌟 ปรับ constructor

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  Key _topBarKey = UniqueKey();
  // State Variables
  bool _isPressed = false;
  

  // [UPDATED] รับค่าจาก AudioManager แทนการ Hardcode
  bool _isMuted = false;
  double _musicVolume = 0.7;
  double _sfxVolume = 0.7;

  // Auth State
  User? _currentUser;
  final _supabase = Supabase.instance.client;

  // [ADDED] ตัวจัดการเสียง
  final AudioManager _audioManager = AudioManager();

  @override
  void initState() {
    super.initState();
    _currentUser = _supabase.auth.currentUser;

    _supabase.auth.onAuthStateChange.listen((data) async {
      if (mounted) {
        final newUser = data.session?.user;
        
        // ตรวจสอบการผูกบัญชี (ถ้ามี)
        final prefs = await SharedPreferences.getInstance();
        final linkOriginalEmail = prefs.getString('linking_original_email');
        final savedRefreshToken = prefs.getString('linking_original_refresh_token');
        
        if (linkOriginalEmail != null && linkOriginalEmail.isNotEmpty && newUser != null) {
          // กำลังอยู่ในโหมดผูกบัญชี
          if (newUser.email != linkOriginalEmail) {
            // อีเมลไม่ตรงกัน → กู้คืน Session เดิม
            await prefs.remove('linking_original_email');
            await prefs.remove('linking_original_refresh_token');
            
            if (savedRefreshToken != null && savedRefreshToken.isNotEmpty) {
              // ออกจาก Google session ที่เพิ่งเข้ามา แล้วกู้คืนบัญชีเดิม
              await _supabase.auth.setSession(savedRefreshToken);
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('อีเมลไม่ตรงกับบัญชีเดิม การผูกบัญชีล้มเหลว')),
              );
            }
            return; // หยุด ไม่ต้อง setState เพราะ setSession จะ trigger onAuthStateChange อีกรอบ
          } else {
            // อีเมลตรงกัน (ผูกสำเร็จ)
            await prefs.remove('linking_original_email');
            await prefs.remove('linking_original_refresh_token');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ผูกบัญชีสำเร็จ!')),
              );
            }
          }
        }

        if (mounted) {
          setState(() {
            _currentUser = newUser;
            _topBarKey = UniqueKey(); // รีเฟรช TopBar ทุกครั้งที่ Session เปลี่ยน
          });
        }
      }
    });

    // [ADDED] โหลดค่าเสียงปัจจุบันมาแสดง
    _loadAudioSettings();
  }

  void _loadAudioSettings() {
    setState(() {
      _isMuted = _audioManager.isMuted;
      _musicVolume = _audioManager.musicVolume;
      _sfxVolume = _audioManager.sfxVolume;
    });
  }

  // ฟังก์ชัน Logout
  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      // เมื่อ SignOut เสร็จ onAuthStateChange จะทำงานและรีเฟรชหน้าจอเป็น Guest เอง
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ออกจากระบบเรียบร้อย')));

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // ฟังก์ชัน Login (จำลองการไปหน้า Login)
  void _handleLogin() {
    // Navigator.pushNamed(context, '/login'); หรือ
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ผูกบัญชี Google
  Future<void> _linkWithGoogle() async {
    try {
      // 1. บันทึก Email และ Refresh Token ปัจจุบันไว้ก่อน (เพื่อกู้คืนถ้าล้มเหลว)
      final currentSession = _supabase.auth.currentSession;
      if (_currentUser?.email != null && currentSession != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('linking_original_email', _currentUser!.email!);
        await prefs.setString('linking_original_refresh_token', currentSession.refreshToken ?? '');
      }

      // 2. เรียก OAuth (จะเด้งไปหน้าเว็บ)
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google link failed: $e')),
        );
      }
    }
  }

  // ผูกบัญชี Email (ตั้งรหัสผ่าน)
  void _linkWithEmail() {
    _showSetPasswordDialog();
  }

  // Popup ตั้งรหัสผ่านเพื่อผูกบัญชี Email
  void _showSetPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFAAD7EA),
                    width: 3,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "ผูกบัญชี Email",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00385D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "ตั้งรหัสผ่านสำหรับ ${_currentUser?.email ?? ''}",
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // รหัสผ่าน
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "รหัสผ่าน",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFAAD7EA), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2374B5), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ยืนยันรหัสผ่าน
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "ยืนยันรหัสผ่าน",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFAAD7EA), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2374B5), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // ยกเลิก
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("ยกเลิก", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // บันทึก
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF85D755), Color(0xFF34C759)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isLoading ? null : () async {
                                final password = passwordController.text.trim();
                                final confirmPassword = confirmPasswordController.text.trim();

                                if (password.isEmpty || confirmPassword.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('กรุณากรอกรหัสผ่านให้ครบ')),
                                  );
                                  return;
                                }
                                if (password.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร')),
                                  );
                                  return;
                                }
                                if (password != confirmPassword) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')),
                                  );
                                  return;
                                }

                                setDialogState(() => isLoading = true);

                                try {
                                  await _supabase.auth.updateUser(
                                    UserAttributes(password: password),
                                  );

                                  // เรียก Backend API เพื่ออัปเดต providers ใน auth.users
                                  await api.ApiService.linkEmailProvider();

                                  // รีเฟรช session เพื่อให้ app_metadata อัปเดต
                                  await _supabase.auth.refreshSession();

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('ผูกบัญชี Email สำเร็จ!')),
                                    );
                                    setState(() {
                                      _currentUser = _supabase.auth.currentUser;
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                                    );
                                  }
                                } finally {
                                  if (mounted) setDialogState(() => isLoading = false);
                                }
                              },
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text("บันทึก", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ตรวจสอบสถานะล็อกอิน
    final bool isLoggedIn = _currentUser != null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/bg1.png',
              fit: BoxFit.cover,
            ),
          ),

          // จัดวางเป็น Column เพื่อไม่ให้กรอบขาวทับแถบด้านบน
          Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 10),

              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.82),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFAAD7EA),
                              width: 3,
                            ),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 40),
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(top: 0, bottom: 0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        // --- [LOGIC] ส่วนที่เปลี่ยนตามสถานะ Login ---
                                        if (isLoggedIn) ...[
                                          _buildLoggedInAccountSection(),
                                          _buildLinkedAccountSection(),
                                        ] else ...[
                                          _buildGuestAccountSection(),
                                        ],

                                        // ------------------------------------------
                                        _buildVolumeSettingsSection(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Header Title
                      _buildHeaderTitle(),
                    ],
                  ),
                ),

                // ปุ่ม Logout อยู่ใต้กรอบขาว
                if (isLoggedIn && !widget.hideLogout) ...[  
                  const SizedBox(height: 16),
                  _buildLogoutButton(),
                ],
              ],
            ),
          ),
          ), // close Expanded child of Column
          ],
          ), // close Column
        ],
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
              key: _topBarKey,
              onNotificationTapped: () {
                Navigator.pushReplacementNamed(context, '/notification');
              },
              onSettingsTapped: () {},
            ),
          ),

        // เรียก Back Button
        _buildBackButton(),
      ],
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
          // หน่วงเวลาให้เห็น Animation ปุ่มยุบตัวนิดนึง
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;
          
          setState(() => _isPressed = false);

          // 🌟 ใช้คำสั่ง pop เพื่อปิดหน้า Setting ทิ้ง ระบบจะเผยให้เห็นหน้าก่อนหน้าอัตโนมัติ
          Navigator.pop(context, true); 
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

  // =========================================================
  // UI ส่วนที่ 1: สำหรับ User ที่ Login แล้ว (จาก SettingLoginPage)
  // =========================================================
  Widget _buildLoggedInAccountSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/icon/iconPerson.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 10),
              const Text(
                "บัญชีผู้ใช้",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 3,
            width: double.infinity,
            color: const Color(0xFFCCE7F2),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFBADEEE),
              borderRadius: BorderRadius.circular(10),
            ),
            // แสดง Email จริงถ้ามี หรือแสดง default
            child: Row(
              children: [
                const Text(
                  "อีเมล : ",
                  style: TextStyle(fontSize: 18, color: Colors.black87),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _currentUser?.email ?? 'xxxxxx@gmail.com',
                      style: const TextStyle(fontSize: 18, color: Colors.black87),
                      maxLines: 1,
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

  Widget _buildLinkedAccountSection() {
    // 1. ดึง User ปัจจุบัน
    final user = Supabase.instance.client.auth.currentUser;

    // 2. ดึง List ของ Providers ที่ User มี (เช่น ['email', 'google'])
    // ถ้าไม่มีให้เป็น List ว่าง
    final List<dynamic> providers = user?.appMetadata['providers'] ?? [];

    // 3. เช็คเงื่อนไขง่ายๆ
    final isGoogleConnected = providers.contains('google');
    final isEmailConnected = providers.contains('email');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "เชื่อมโยงบัญชี",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 3, color: Color(0xFFCCE7F2)),
          const SizedBox(height: 6),

          // --- Google Row ---
          _buildProviderRow(
            iconPath: 'assets/images/icon/iconGoogle.png',
            label: 'Google',
            isConnected: isGoogleConnected,
            onTap: isGoogleConnected ? null : _linkWithGoogle,
          ),

          const SizedBox(height: 6),

          // --- Email Row ---
          _buildProviderRow(
            iconPath: 'assets/images/icon/iconEmail.png',
            label: 'Email',
            isConnected: isEmailConnected,
            onTap: isEmailConnected ? null : _linkWithEmail,
          ),
        ],
      ),
    );
  }

  // แยก Widget ย่อยออกมาเพื่อให้โค้ดสะอาดขึ้น
  Widget _buildProviderRow({
    required String iconPath,
    required String label,
    required bool isConnected,
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Image.asset(iconPath, width: 40, height: 40),
        const SizedBox(width: 15),
        Text(label, style: const TextStyle(fontSize: 18, color: Colors.black)),
        const Spacer(),
        if (isConnected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2374B5),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              "เชื่อมต่อแล้ว",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          )
        else if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: const Color(0xFF2374B5), width: 2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                "ผูกบัญชี",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================
  // UI ส่วนที่ 2: สำหรับ Guest / ยังไม่ Login (จาก SettingLogoutPage)
  // =========================================================
  Widget _buildGuestAccountSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          // Section Header
          Row(
            children: [
              Image.asset(
                'assets/images/icon/iconPerson.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 10),
              const Text(
                "บัญชีผู้ใช้",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Divider
          Container(
            height: 3,
            width: double.infinity,
            color: const Color(0xFFCCE7F2),
          ),
          const SizedBox(height: 20),

          // Guest Character Image
          Center(
            child: Image.asset(
              'assets/images/profile/setting-character.png',
              width: 140,
            ),
          ),
          const SizedBox(height: 10),

          // "Not Logged In" Text
          const Center(
            child: Text(
              "ยังไม่ได้เข้าสู่ระบบ",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Login Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleLogin, // เรียกฟังก์ชัน Login
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF556AEB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "เข้าสู่ระบบ",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // UI ส่วนที่ 3: Shared (ใช้ร่วมกัน)
  // =========================================================

  Widget _buildVolumeSettingsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/icon/iconVolume.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 10),
              const Text(
                "ระดับเสียง",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: double.infinity,
            color: const Color(0xFFCCE7F2),
          ),
          const SizedBox(height: 5),
          const SizedBox(height: 5),

          // Game Sound Toggle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFBADEEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "เสียงเกม",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    // คำนวณสถานะใหม่ และสั่งงาน AudioManager
                    final newMuteState = !_isMuted;
                    await _audioManager.toggleMute(newMuteState);

                    setState(() {
                      _isMuted = newMuteState;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 70,
                    height: 32,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: !_isMuted
                          ? const Color(0xFF002A50)
                          : Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF002A50),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (!_isMuted)
                          const Positioned(
                            left: 8,
                            top: 2,
                            bottom: 2,
                            child: Center(
                              child: Text(
                                "ON",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                        if (_isMuted)
                          const Positioned(
                            right: 8,
                            top: 2,
                            bottom: 2,
                            child: Center(
                              child: Text(
                                "OFF",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),

                        AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: !_isMuted
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2374B5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // [UPDATED] Music Slider เชื่อมต่อกับ _audioManager
          _buildVolumeSlider(
            label: "เสียงเพลงประกอบฉาก",
            value: _musicVolume,
            onChanged: (val) {
              setState(() => _musicVolume = val); // อัปเดต UI
              _audioManager.setMusicVolume(val); // อัปเดตเสียงจริง
            },
          ),
          const SizedBox(height: 6),

          // [UPDATED] SFX Slider เชื่อมต่อกับ _audioManager
          _buildVolumeSlider(
            label: "เสียงเอฟเฟค",
            value: _sfxVolume,
            onChanged: (val) {
              setState(() => _sfxVolume = val); // อัปเดต UI
              _audioManager.setSfxVolume(val); // อัปเดตเสียงจริง
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 6, 15, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFBADEEE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label [ ${(value * 100).toInt()}% ]",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final newValue = (value - 0.1).clamp(0.0, 1.0);
                  onChanged(newValue);
                },
                child: const Icon(
                  Icons.arrow_left,
                  size: 50,
                  color: Color(0xFF2374B5),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 10,
                      trackShape: const GradientRectSliderTrackShape(
                        gradient: LinearGradient(
                          colors: [Color(0xFF59ABEC), Color(0xFF85D755)],
                        ),
                        darkenInactive: false,
                      ),
                      thumbShape: const CircleThumbShape(
                        thumbRadius: 10,
                        thumbColor: Color(0xFF2374B5),
                        borderColor: Color(0xFF002A50),
                        borderWidth: 2,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12.0,
                      ),
                      overlayColor: const Color(0xFF2374B5).withOpacity(0.2),
                      activeTrackColor: Colors.transparent, // Handled by shape
                      inactiveTrackColor: Colors
                          .white, // Handled by shape but used as fallback/param
                    ),
                    child: Slider(value: value, onChanged: onChanged),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  final newValue = (value + 0.1).clamp(0.0, 1.0);
                  onChanged(newValue);
                },
                child: const Icon(
                  Icons.arrow_right,
                  size: 50,
                  color: Color(0xFF2374B5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: ElevatedButton(
          onPressed: _handleLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE94444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 3,
          ),
          child: const Text(
            "ออกจากระบบ",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2374B5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            "ตั้งค่า",
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
}

// =========================================================
// Custom Slider Shapes (Helper Classes)
// =========================================================

class CircleThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final Color thumbColor;
  final Color borderColor;
  final double borderWidth;

  const CircleThumbShape({
    this.thumbRadius = 12.0,
    required this.thumbColor,
    required this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final Paint fillPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, thumbRadius, fillPaint);
    canvas.drawCircle(center, thumbRadius, borderPaint);
  }
}

class GradientRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  final LinearGradient gradient;
  final bool darkenInactive;

  const GradientRectSliderTrackShape({
    this.gradient = const LinearGradient(
      colors: [Colors.lightBlue, Colors.blue],
    ),
    this.darkenInactive = true,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..style = PaintingStyle.fill;

    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white
      ..style = PaintingStyle.fill;

    final Radius radius = Radius.circular(trackRect.height / 2);

    final RRect fullRRect = RRect.fromRectAndRadius(trackRect, radius);

    context.canvas.save();
    context.canvas.clipRect(
      Rect.fromLTRB(
        thumbCenter.dx,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
      ),
    );
    context.canvas.drawRRect(fullRRect, inactivePaint);
    context.canvas.restore();

    context.canvas.save();
    context.canvas.clipRect(
      Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        thumbCenter.dx,
        trackRect.bottom,
      ),
    );
    context.canvas.drawRRect(fullRRect, activePaint);
    context.canvas.restore();
  }
}
