import 'package:flutter/material.dart';

class MenuItem {
  final String imagePath;
  final String label;
  final VoidCallback onTap;
  final bool hasNotification;

  MenuItem({
    required this.imagePath,
    required this.label,
    required this.onTap,
    this.hasNotification = false,
  });
}

class RightSideMenu extends StatelessWidget {
  final List<MenuItem> menuItems;

  const RightSideMenu({
    Key? key,
    required this.menuItems,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      top: 20,
      child: Column(
        children: menuItems.map((item) => _MenuItemButton(item: item)).toList(),
      ),
    );
  }
}

class _MenuItemButton extends StatefulWidget {
  final MenuItem item;
  const _MenuItemButton({required this.item});

  @override
  State<_MenuItemButton> createState() => _MenuItemButtonState();
}

class _MenuItemButtonState extends State<_MenuItemButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.item.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 16),
        transform: Matrix4.identity()
          ..translate(30.0, 30.0)
          ..scale(_isPressed ? 0.88 : 1.0)
          ..translate(-30.0, -30.0),
        child: Column(
          children: [
            // รูปภาพ
            Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  widget.item.imagePath,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 30,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
                if (widget.item.hasNotification)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE53935),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // ข้อความ
            Text(
              widget.item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5D4037),
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}