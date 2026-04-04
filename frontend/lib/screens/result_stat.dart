import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';

class ResultStatScreen extends StatefulWidget {
  final Map<String, int> statusRewards;
  final User? user;

  const ResultStatScreen({Key? key, required this.statusRewards, this.user})
    : super(key: key);

  @override
  State<ResultStatScreen> createState() => _ResultStatScreenState();
}

class _ResultStatScreenState extends State<ResultStatScreen> {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarHeight = 75.0 + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/bg11.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Color(0xFFE8F5E9));
              },
            ),
          ),

          // Main Content
          Positioned.fill(
            top: topBarHeight + 80,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 กล่องหลัก
                    Container(
                      constraints: BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFF9DD0E7), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ✅ Success Text + Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/icon/check2.png', // 🔥 เปลี่ยนเป็นรูปคุณ
                                height: 50,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.check_circle, size: 30);
                                },
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ทำกิจกรรมสำเร็จ',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                          // ✅ รูปตัวละคร (ใส่ภาพทีหลังได้)
                          Image.asset(
                            'assets/images/profile/profile-character.png', // 🔥 เปลี่ยนเป็นรูปคุณ
                            height: 250,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.person, size: 100);
                            },
                          ),

                          SizedBox(height: 20),

                          // ✅ Title
                          Text(
                            'ค่าสถานะที่ได้รับ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          SizedBox(height: 12),

                          // ✅ Status List
                          Column(
                            children: widget.statusRewards.entries.map((entry) {
                              final isIncreased = entry.value > 0;
                              return _buildStatusRow(
                                entry.key,
                                entry.value,
                                isIncreased,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ✅ ปุ่มเสร็จสิ้น
                    Container(
                      width: 180,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF556AEB), Color(0xFF59ABEC)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Text(
                          'เสร็จสิ้น',
                          style: TextStyle(
                            fontSize: 20,
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
          ),

          // Top Bar
          _buildTopBar(topPadding, topBarHeight),

          // Blue Header
          _buildBlueHeader(topBarHeight),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String statusName, int value, bool isIncreased) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              statusName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              isIncreased ? '+$value' : '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isIncreased ? Color(0xFF4CAF50) : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header with Back Button & Title
  Widget _buildBlueHeader(double topOffset) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF015496), Color(0xFF2273B4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            /// Title (อยู่กลางจริง)
            const Center(
              child: Text(
                "ผลลัพธ์หลังทำกิจกรรม",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(double topPadding, double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: height,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomCenter,
        child: CustomTopBar(
          onNotificationTapped: () =>
              Navigator.pushNamed(context, '/notification'),
          onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
        ),
      ),
    );
  }
}
