import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MissionFailPopup extends StatefulWidget {
  final String elapsedTime;
  final VoidCallback onTapContinue;

  const MissionFailPopup({
    super.key,
    required this.elapsedTime,
    required this.onTapContinue,
  });

  static Future<void> show(
    BuildContext context, {
    required String elapsedTime,
    required VoidCallback onTapContinue,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => MissionFailPopup(
        elapsedTime: elapsedTime,
        onTapContinue: onTapContinue,
      ),
    );
  }

  @override
  State<MissionFailPopup> createState() => _MissionFailPopupState();
}

class _MissionFailPopupState extends State<MissionFailPopup>
    with SingleTickerProviderStateMixin {
  
  // ==========================================
  // Zone 1: Animations & State Initialization
  // ==========================================
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 350),
    vsync: this,
  )..forward();

  late final Animation<double> _scaleAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeIn,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ==========================================
  // Zone 2: Main Layout Build
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTapContinue();
        Navigator.pop(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildPopupContent(context),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Zone 3: UI Components Builder
  // ==========================================
  Widget _buildPopupContent(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 380;
    
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(isSmallScreen),
          const SizedBox(height: 10),
          _buildTimeDisplay(isSmallScreen),
        ],
      ),
    );
  }

  // Header Title Component
  Widget _buildTitle(bool isSmall) {
    final iconSize = isSmall ? 24.0 : 30.0;
    final titleFontSize = isSmall ? 28.0 : 36.0;
    final spacing = isSmall ? 10.0 : 15.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/images/design/star.png', width: iconSize, height: iconSize),
        SizedBox(width: spacing),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFB0B0B0)],
          ).createShader(bounds),
          child: Text(
            'ภารกิจล้มเหลว',
            style: GoogleFonts.kanit(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
            ),
          ),
        ),
        SizedBox(width: spacing),
        Image.asset('assets/images/design/star.png', width: iconSize, height: iconSize),
      ],
    );
  }

  // Center Time Display Component
  Widget _buildTimeDisplay(bool isSmall) {
    final labelFontSize = isSmall ? 16.0 : 18.0;
    final timeFontSize = isSmall ? 24.0 : 28.0;
    final hintFontSize = isSmall ? 14.0 : 16.0;
    final verticalPadding = isSmall ? 20.0 : 30.0;
    final spacing = isSmall ? 10.0 : 15.0;
    final largeSpacing = isSmall ? 25.0 : 35.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.25, 0.75, 1.0],
          colors: [
            const Color(0xFFC6F4FF).withOpacity(0.25),
            const Color(0xFF000000).withOpacity(0.45),
            const Color(0xFF000000).withOpacity(0.45),
            const Color(0xFFC6F4FF).withOpacity(0.25),
          ],
        ),
        border: const Border.symmetric(horizontal: BorderSide(color: Colors.white, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'เวลาที่ใช้',
            style: GoogleFonts.kanit(color: Colors.white, fontSize: labelFontSize, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: spacing),
          Text(
            widget.elapsedTime,
            style: GoogleFonts.kanit(color: Colors.white, fontSize: timeFontSize, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: largeSpacing),
          Text(
            'แตะเพื่อดำเนินการต่อ',
            style: GoogleFonts.kanit(color: Colors.white70, fontSize: hintFontSize),
          ),
        ],
      ),
    );
  }
}
