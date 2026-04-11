import 'package:flutter/material.dart';

class ClubButton extends StatelessWidget {
  final String label;
  final String iconPath;
  final List<Color> gradientColors;
  final Color iconBgColor;
  final Color shadowColor;
  final VoidCallback onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;

  const ClubButton({
    super.key,
    required this.label,
    required this.iconPath,
    required this.gradientColors,
    required this.iconBgColor,
    required this.shadowColor,
    required this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final buttonHeight = size.height * 0.085 > 75.0
        ? 75.0
        : size.height * 0.085;
    final iconSize = buttonHeight * 0.65;

    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => onTapDown?.call(),
      onTapUp: (_) => onTapUp?.call(),
      onTapCancel: onTapCancel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          height: buttonHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 8,
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(iconPath, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 26, right: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: size.width * 0.046 > 18
                          ? 18
                          : size.width * 0.046,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}