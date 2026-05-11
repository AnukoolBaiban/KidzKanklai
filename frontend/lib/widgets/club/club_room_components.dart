import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';

class ClubBackground extends StatelessWidget {
  const ClubBackground({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        'assets/images/background/bg15.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE2F5FD)),
      ),
    );
  }
}

class ClubTopBar extends StatelessWidget {
  final double topPadding;
  const ClubTopBar({super.key, required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      color: Colors.black.withValues(alpha: 0.4),
      child: CustomTopBar(
        onNotificationTapped: () =>
            Navigator.pushNamed(context, '/notification'),
        onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
      ),
    );
  }
}

class ClubBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final bool pushReplacement;
  const ClubBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.pushReplacement = true,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: CustomBottomNavigationBar(
          selectedIndex: selectedIndex,
          onItemTapped: (index) {
            if (index == 3) return; // ไม่กดซ้ำปุ่มชมรมเมื่ออยู่หน้าชมรมอยู่แล้ว
            onItemTapped(index);
            const routes = ['/fashion', '/lobby', '/map', '/club'];
            if (index < routes.length) {
              if (pushReplacement) {
                Navigator.pushReplacementNamed(context, routes[index]);
              } else {
                Navigator.pushNamed(context, routes[index]);
              }
            }
          },
          onAvatarTapped: () => Navigator.pushNamed(context, '/profile'),
        ),
      ),
    );
  }
}

class ClubBlueHeader extends StatefulWidget {
  final String title;
  final VoidCallback? onBackPressed;

  const ClubBlueHeader({
    super.key,
    required this.title,
    this.onBackPressed,
  });

  @override
  State<ClubBlueHeader> createState() => _ClubBlueHeaderState();
}

class _ClubBlueHeaderState extends State<ClubBlueHeader> {
  bool _isBackPressed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF015496), Color(0xFF2273B4)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.onBackPressed != null ? 60 : 30,
                  ),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onBackPressed != null)
              Positioned(
                left: 20,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _isBackPressed = true),
                  onTapCancel: () => setState(() => _isBackPressed = false),
                  onTap: () async {
                    setState(() => _isBackPressed = false);
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (widget.onBackPressed != null) widget.onBackPressed!();
                  },
                  child: Image.asset(
                    _isBackPressed
                        ? 'assets/images/button/bt-hover-Back.png'
                        : 'assets/images/button/bt-Back.png',
                    width: 50,
                    height: 50,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEEEEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF333333),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
    );
  }
}