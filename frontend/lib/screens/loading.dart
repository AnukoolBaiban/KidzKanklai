import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/rive_cache.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  // State variable to track the number of dots (0-3)
  int _dotCount = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
    _loadResources();
  }

  Future<void> _loadResources() async {
    // 1. Load Rive File
    await RiveCache().loadAsset('assets/animation/Model2.0.riv');
    
    // 2. Add other preload logic here if needed (e.g. user data)
    
    // 3. Navigate to next screen
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/startgame'); 
    }
  }

  /// Starts the periodic timer to animate the dots.
  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _dotCount++;
          if (_dotCount > 3) {
            _dotCount = 0; // Reset to 0 (no dots)
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: 30),
            _buildLoadingText(),
          ],
        ),
      ),
    );
  }

  /// Widget to display the logo image
  Widget _buildLogo() {
    return Image.asset(
      'assets/images/icon/icon-white-loading.png',
      height: 120,
      fit: BoxFit.contain,
    );
  }

  /// Widget to display the animated "Loading..." text
  Widget _buildLoadingText() {
    String dots = '.' * _dotCount;

    return Text(
      'Loading$dots',
      style: GoogleFonts.josefinSans(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}
