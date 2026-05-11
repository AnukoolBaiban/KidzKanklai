// lib/config/app_config.dart

class AppConfig {
  // ----------------------------------------------------------
  // 🛠️ แก้แค่ตรงนี้บรรทัดเดียว เมื่อเปลี่ยนคอม หรือเปลี่ยน WiFi
  // ----------------------------------------------------------

  // สำหรับ Chrome Web (บนคอมเครื่องเดียวกัน): ใช้ localhost
  //static const String baseUrl = 'http://localhost:8080';

  // สำหรับเครื่องจริง (Real Device): ใช้ IP WI-FI ของคอมพิวเตอร์
  //static const String baseUrl = 'http://192.168.1.47:8080'; //สำหรับทั่วไป
  //static const String baseUrl = 'http://10.7.146.102:8080'; //สำหรับมหาวิทยาลัย
  //static const String baseUrl = 'http://10.47.14.149:8080'; //สำหรับเน็ตมือถือ

  // สำหรับ Android Emulator: ให้เปิดบรรทัดนี้แทน
  //static const String baseUrl = 'http://10.0.2.2:8080';

  // สำหรับใช้งานจริงบน Render (Deploy)
  static const String baseUrl = 'https://kidzkanklai-b78c.onrender.com';
}
