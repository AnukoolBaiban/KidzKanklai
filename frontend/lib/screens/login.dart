import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/screens/register.dart';
import 'package:flutter_application_1/screens/forgotpw.dart';
import 'package:flutter_application_1/screens/profile.dart';
import 'package:flutter_application_1/screens/lobby.dart';
import 'package:flutter_application_1/api_service.dart'; // Import ApiService

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();

    // 👇 ฟังการเปลี่ยนแปลงสถานะ login (สำคัญสำหรับ Google OAuth)
    _authStream = Supabase.instance.client.auth.onAuthStateChange;

    _authStream.listen((data) {
      final session = data.session;
      if (session != null && mounted) {
        // ✅ Save Token to ApiService
        ApiService.authToken = session.accessToken;
        print("Token Saved: ${session.accessToken.substring(0, 10)}...");
        
        Navigator.pushReplacementNamed(context, '/lobby');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 🔐 Login ด้วย Email/Password
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกอีเมลและรหัสผ่าน')),
      );
      return;
    }

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เข้าสู่ระบบสำเร็จ')),
        );
        
        // Save Token (Explicitly)
        if (res.session != null) {
           ApiService.authToken = res.session!.accessToken;
        }

        Navigator.pushReplacementNamed(context, '/lobby');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  /// 🔑 Login ด้วย Google
  Future<void> _loginWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF556AEB);
    final backgroundColor = Colors.white;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/bg2.png',
              fit: BoxFit.cover,
            ),
          ),
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
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Image.asset(
                              'assets/images/icon/logo.png',
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const Text(
                            "ยินดีต้อนรับกลับสู่ห้องเรียน",
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "เข้าสู่ระบบ",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 32),

                          TextField(
                            controller: _emailController,
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
                          const SizedBox(height: 16),

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelText: "รหัสผ่าน",
                              prefixIcon: Icon(Icons.lock, color: primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                          const SizedBox(height: 10),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ForgotPWScreen()),
                                );
                              },
                              child: Text(
                                "ลืมรหัสผ่านใช่ไหม?",
                                style: TextStyle(color: primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                "เข้าสู่ระบบ",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loginWithGoogle,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                elevation: 3,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/icon/iconGoogle.png',
                                    height: 36,
                                    width: 36,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "เข้าสู่ระบบผ่าน Google",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

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
