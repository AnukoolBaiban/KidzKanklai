// lib/config/app_config.dart

class AppConfig {
  // ----------------------------------------------------------
  // 🛠️ แก้แค่ตรงนี้บรรทัดเดียว เมื่อเปลี่ยนคอม หรือเปลี่ยน WiFi
  // ----------------------------------------------------------

  // สำหรับ Chrome Web (บนคอมเครื่องเดียวกัน): ใช้ localhost
  static const String baseUrl = 'http://localhost:8080';

  // สำหรับเครื่องจริง (Real Device): ใช้ IP ของคอมพิวเตอร์
  // static const String baseUrl = 'http://192.168.1.39:8080';

  // สำหรับ Android Emulator: ให้เปิดบรรทัดนี้แทน
  //static const String baseUrl = 'http://10.0.2.2:8080';
}
