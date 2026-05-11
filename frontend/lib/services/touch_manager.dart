import 'package:flutter/material.dart';

// ─── TouchRippleLayer ─────────────────────────────────────────────────────────
// Widget ห่อทั้งแอปเพื่อสร้าง effect คลื่นน้ำ (water ripple) ทุกครั้งที่แตะหน้าจอ
//
// วิธีใช้ — เพิ่มใน MaterialApp.builder ครั้งเดียว:
//
//   MaterialApp(
//     builder: (context, child) => TouchRippleLayer(child: child!),
//     ...
//   )
//
// หลักการทำงาน:
//   - Listener.onPointerDown → สร้าง ripple ที่ตำแหน่งที่กด
//   - Ripple จะค่อยๆ ขยายออกเป็นวงกลมแล้วจางหายไป เหมือนคลื่นน้ำ
//   - รองรับการกดหลายจุดพร้อมกัน (multi-touch)

class TouchRippleLayer extends StatefulWidget {
  final Widget child;

  const TouchRippleLayer({super.key, required this.child});

  @override
  State<TouchRippleLayer> createState() => _TouchRippleLayerState();
}

class _TouchRippleLayerState extends State<TouchRippleLayer> {
  // เก็บรายการ ripple ที่กำลังแสดงอยู่
  final List<_RippleData> _ripples = [];

  void _addRipple(Offset position) {
    setState(() {
      _ripples.add(_RippleData(
        key: UniqueKey(),
        position: position,
      ));
    });
  }

  void _removeRipple(Key key) {
    setState(() {
      _ripples.removeWhere((r) => r.key == key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        _addRipple(event.position);
      },
      child: Stack(
        children: [
          // เนื้อหาหลักของแอป
          widget.child,

          // วาง ripple ทั้งหมดทับไว้ด้านบน (IgnorePointer ทำให้ไม่บล็อก touch event)
          IgnorePointer(
            child: Stack(
              children: _ripples
                  .map((ripple) => _WaterRippleWidget(
                        key: ripple.key,
                        position: ripple.position,
                        onComplete: () => _removeRipple(ripple.key),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ข้อมูล Ripple ─────────────────────────────────────────────────────────────

class _RippleData {
  final Key key;
  final Offset position;

  _RippleData({required this.key, required this.position});
}

// ─── Water Ripple Widget ───────────────────────────────────────────────────────
// วาด ripple effect แบบคลื่นน้ำ — มีหลายวง (ring) ขยายออกทีละวง แล้วค่อยๆ จาง

class _WaterRippleWidget extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const _WaterRippleWidget({
    super.key,
    required this.position,
    required this.onComplete,
  });

  @override
  State<_WaterRippleWidget> createState() => _WaterRippleWidgetState();
}

class _WaterRippleWidgetState extends State<_WaterRippleWidget>
    with TickerProviderStateMixin {
  // จำนวนวง ripple ที่จะสร้าง
  static const int _ringCount = 3;

  // ระยะเวลา animation ของแต่ละวง
  static const Duration _ringDuration = Duration(milliseconds: 900);

  // ช่วงเวลาระหว่างวงแต่ละวง (stagger)
  static const Duration _staggerDelay = Duration(milliseconds: 150);

  // ขนาดสูงสุดของ ripple (รัศมี)
  static const double _maxRadius = 80.0;

  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _radiusAnimations = [];
  final List<Animation<double>> _opacityAnimations = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < _ringCount; i++) {
      final controller = AnimationController(
        duration: _ringDuration,
        vsync: this,
      );

      // วงขยายจากเล็กไปใหญ่ ด้วย Curve ที่ดูเหมือนน้ำ
      final radiusAnim = Tween<double>(begin: 0.0, end: _maxRadius).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      );

      // ความโปร่งใส: จางลงจาก 0.5 → 0.0 (วงนอกจะจางกว่าวงแรก)
      final opacityAnim = Tween<double>(
        begin: 0.45 - (i * 0.1), // วงที่ 2, 3 เริ่มจางกว่า
        end: 0.0,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );

      _controllers.add(controller);
      _radiusAnimations.add(radiusAnim);
      _opacityAnimations.add(opacityAnim);

      // เริ่ม animation แบบ stagger (วงที่ 2 เริ่มช้ากว่าวงที่ 1)
      Future.delayed(_staggerDelay * i, () {
        if (mounted) {
          controller.forward().then((_) {
            // ถ้าเป็นวงสุดท้ายเสร็จแล้ว → ลบ ripple ออก
            if (i == _ringCount - 1 && mounted) {
              widget.onComplete();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(_controllers),
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _WaterRipplePainter(
            center: widget.position,
            radii: _radiusAnimations.map((a) => a.value).toList(),
            opacities: _opacityAnimations.map((a) => a.value.clamp(0.0, 1.0)).toList(),
          ),
        );
      },
    );
  }
}

// ─── CustomPainter สำหรับวาดวงกลมคลื่นน้ำ ────────────────────────────────────

class _WaterRipplePainter extends CustomPainter {
  final Offset center;
  final List<double> radii;
  final List<double> opacities;

  _WaterRipplePainter({
    required this.center,
    required this.radii,
    required this.opacities,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < radii.length; i++) {
      if (radii[i] <= 0 || opacities[i] <= 0) continue;

      // วาดวงแหวน (ไม่ใช่วงกลมทึบ) เพื่อให้ดูเหมือนคลื่นน้ำจริงๆ
      final paint = Paint()
        ..color = const Color(0xFF64B5F6).withOpacity(opacities[i]) // สีฟ้าอ่อน
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 - (i * 0.5) // วงนอกบางกว่าวงใน
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0); // เบลอเล็กน้อย

      canvas.drawCircle(center, radii[i], paint);

      // วาดวงเติมสีจางๆ ข้างในเพื่อให้ดูเหมือนผิวน้ำ
      if (i == 0) {
        final fillPaint = Paint()
          ..color = const Color(0xFF90CAF9).withOpacity(opacities[i] * 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radii[i], fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WaterRipplePainter oldDelegate) {
    return true; // วาดใหม่ทุก frame เพราะ animation เปลี่ยนตลอด
  }
}
