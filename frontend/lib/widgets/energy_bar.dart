import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🌟 1. นำเข้า Supabase

class EnergyBar extends StatefulWidget {
  const EnergyBar({super.key});

  @override
  State<EnergyBar> createState() => _EnergyBarState();
}

class _EnergyBarState extends State<EnergyBar> {
  // 🌟 ตัวแปรเก็บข้อมูลจากฐานข้อมูล
  int _energy = 0;
  int _maxEnergy = 100; // 🌟 กำหนดค่าพลังงานสูงสุด (Max Energy) เอาไว้ที่ 100 ก่อน
  int _ticket = 0;
  bool _isLoading = true;

  // 🌟 ตัวแปรเก็บ Subscription สำหรับฟังข้อมูล Real-time
  RealtimeChannel? _energySubscription;
  RealtimeChannel? _ticketSubscription;

  @override
  void initState() {
    super.initState();
    _fetchEnergyDataAndListen(); // สั่งให้ดึงข้อมูลครั้งแรกและเริ่มดักฟัง
  }

  @override
  void dispose() {
    // 🌟 สั่งปิดการฟังแบบ Real-time เมื่อ Widget นี้ถูกทำลาย (สำคัญมาก ป้องกัน Memory Leak)
    _energySubscription?.unsubscribe();
    _ticketSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchEnergyDataAndListen() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // --- ส่วนที่ 1: ดึงข้อมูลครั้งแรก (Initial Fetch) ---
      final charResponse = await Supabase.instance.client
          .from('characters')
          .select('stamina')
          .eq('user_id', userId)
          .maybeSingle();

      final ticketResponse = await Supabase.instance.client
          .from('collect')
          .select('quantity')
          .eq('user_id', userId)
          .eq('item_id', 21)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _energy = charResponse != null ? (charResponse['stamina'] ?? 0) : 0;
          _ticket = ticketResponse != null ? (ticketResponse['quantity'] ?? 0) : 0;
          _isLoading = false;
        });
      }

      // --- ส่วนที่ 2: เริ่มดักฟังการเปลี่ยนแปลง (Real-time Listeners) ---
      
      // 🌟 ดักฟังตาราง characters (ฟังเฉพาะ user ปัจจุบัน)
      _energySubscription = Supabase.instance.client
          .channel('public:characters')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'characters',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (mounted) {
                setState(() {
                  _energy = payload.newRecord['stamina'] ?? _energy;
                });
              }
            },
          )
          .subscribe();

      // 🌟 ดักฟังตาราง collect (ฟังเฉพาะ user ปัจจุบัน และตั๋ว item_id = 21)
      _ticketSubscription = Supabase.instance.client
          .channel('public:collect:ticket')
          .onPostgresChanges(
            event: PostgresChangeEvent.update, // สนใจเฉพาะตอนค่า quantity ขยับ
            schema: 'public',
            table: 'collect',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              // เช็คซ้ำอีกรอบว่าเป็นของ item_id: 21 จริงๆ
              if (mounted && payload.newRecord['item_id'] == 21) {
                setState(() {
                  _ticket = payload.newRecord['quantity'] ?? _ticket;
                });
              }
            },
          )
          .subscribe();

    } catch (e) {
      debugPrint("Error fetching EnergyBar data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 375;
    final size = MediaQuery.of(context).size;
    final titleFontSize = (size.width * 0.038).clamp(14.0, 18.0);

    // 🌟 คำนวณหลอด Progress แบบป้องกันไม่ให้หลอดทะลุเกิน 100% (clamp)
    double progress = _maxEnergy > 0 ? (_energy / _maxEnergy).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        // 🌟 เปลี่ยนกลับเป็นแบบกระจายตัวเต็มพื้นที่ 
        children: [
          /// Thunder icon
          Image.asset(
            "assets/images/item/energy.png",
            width: 10 * scale,
          ),
          SizedBox(width: 4 * scale),

          /// Energy number
          Text(
            _isLoading ? "..." : "$_energy",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
          SizedBox(width: 8 * scale),

          /// Energy progress bar
          // 🌟 คืนค่า Expanded ครอบคอนเทนเนอร์เพื่อให้หลอดยืดหดได้ตามที่ว่าง
          Expanded(
            child: Container(
              height: 12 * scale,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF85D755), Color(0xFF8EFF4C)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10 * scale),

          /// Ticket icon
          Image.asset(
            "assets/images/item/Ticket_energy_img.png",
            width: 22 * scale,
          ),
          SizedBox(width: 4 * scale),

          /// Ticket counter
          Text(
            _isLoading ? "..." : "$_ticket",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
        ],
      ),
    );
  }
}