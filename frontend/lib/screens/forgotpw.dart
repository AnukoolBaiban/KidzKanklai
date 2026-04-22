import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/screens/register.dart';
import 'package:flutter_application_1/screens/login.dart';
import 'package:flutter_application_1/screens/resetpw.dart'; 

class ForgotPWScreen extends StatefulWidget {
  const ForgotPWScreen({super.key});

  @override
  State<ForgotPWScreen> createState() => _ForgotPWScreenState();
}

class _ForgotPWScreenState extends State<ForgotPWScreen> {
  final TextEditingController _emailController = TextEditingController();
  
  // เพิ่มตัวแปรสำหรับ Loading
  bool _isLoading = false; 
  // เรียก instance ของ Supabase
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // --- ส่วนที่เพิ่ม: ดักจับตอน User กดลิงก์จากอีเมลกลับมา ---
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        // เมื่อเป็นเหตุการณ์กู้คืนรหัสผ่าน ให้ไปหน้าตั้งรหัสใหม่
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ResetPWScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // --- ฟังก์ชันส่งอีเมล ---
  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกอีเมล")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutter://reset-callback', // **ต้องตรงกับ AndroidManifest**
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ส่งลิงก์รีเซ็ตไปที่อีเมลแล้ว กรุณาตรวจสอบ Inbox/Junk"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define colors relative to the design (conceptual)
    final primaryColor = const Color(0xFF556AEB);
    final backgroundColor = Colors.white;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/bg2.png',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient Overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Login Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: backgroundColor.withOpacity(0.95),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Image.asset(
                              'assets/images/icon/logo.png',
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Text(
                            "ลืมรหัสผ่าน",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "กรุณากรอกอีเมลของคุณ\nเพื่อรับลิงก์สำหรับตั้งรหัสผ่านใหม่",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Email Input
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: "อีเมล",
                              prefixIcon: Icon(Icons.email, color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Reset Password Button (ปุ่มหลักในการส่งอีเมล)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              // แก้ไข: เรียกฟังก์ชัน _handleResetPassword เมื่อกดปุ่ม
                              onPressed: _isLoading ? null : _handleResetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                elevation: 3,
                              ),
                              child: _isLoading 
                                ? const SizedBox(
                                    height: 20, 
                                    width: 20, 
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  )
                                : const Text(
                                    "รีเซ็ตรหัสผ่าน",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Sign Up & Back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          "สร้างบัญชีใหม่",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Text(
                        "|",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        child: const Text(
                          "กลับไปหน้าเข้าสู่ระบบ",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}