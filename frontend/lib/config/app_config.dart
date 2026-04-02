// lib/config/app_config.dart

class AppConfig {
  // ----------------------------------------------------------
  // 🛠️ แก้แค่ตรงนี้บรรทัดเดียว เมื่อเปลี่ยนคอม เครื่องจำลอง หรือขึ้น Production
  // เปิดคอมเมนต์เฉพาะบรรทัดที่ต้องการใช้งาน
  // ----------------------------------------------------------

  // [1] สำหรับการขึ้น Production (ดึง API จาก Render)
  static const String baseUrl = 'https://kidzkanklai.onrender.com'; // <--- เปลี่ยนตรงนี้เป็น URL จริงของคุณ

  // [2] สำหรับ Chrome Web (บนคอมเครื่องเดียวกัน): ใช้ localhost
  // static const String baseUrl = 'http://localhost:8080';

  // [3] สำหรับเครื่องจริง (Real Device): ใช้ IP ของคอมพิวเตอร์
  // static const String baseUrl = 'http://192.168.155.252:8080';

  // [4] สำหรับ Android Emulator: ให้เปิดบรรทัดนี้แทน
  // static const String baseUrl = 'http://10.0.2.2:8080';
}
