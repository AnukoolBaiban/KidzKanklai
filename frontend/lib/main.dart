import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/screens/all_quest.dart';

import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/forgotpw.dart';
import 'screens/resetpw.dart';
import 'screens/lobby.dart';
import 'screens/all_quest.dart';
import 'screens/countdown_quest.dart';
import 'screens/profile.dart';
import 'screens/notification.dart';
import 'screens/achievement.dart';
import 'screens/lootbox_screen.dart';
import 'screens/map.dart';
import 'screens/gasha.dart';
import 'screens/club_screen.dart';
import 'screens/setting.dart';
import 'screens/startgame.dart';
import 'screens/loading.dart';
import 'screens/me.dart';
import 'screens/fashion.dart';
import 'screens/create_normal_quest.dart';
import 'screens/create_club_quest.dart';
import 'screens/quest_detail.dart';
import 'config/rive_cache.dart';
import 'config/user_pose_provider.dart';
import 'services/audio_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AudioManager().init();

  await Supabase.initialize(
    url: 'https://dregaeeryyqlfssejzbr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyZWdhZWVyeXlxbGZzc2VqemJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NjAzMzgsImV4cCI6MjA4NDAzNjMzOH0.QEyCrkki7K-RgaejMTdYsx-N-dt87Qi1LjJSZ4VFNLw',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Restore Token if session exists
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    ApiService.authToken = session.accessToken;
    print("Restore Token: ${session.accessToken.substring(0, 10)}...");
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserPoseProvider())],
      child: const KidzKanklaiApp(),
    ),
  );
}

// สร้างตัวแปร Global เป็น Observer ตัวใหม่ของเรา
final MusicRouteObserver musicObserver = MusicRouteObserver();

class KidzKanklaiApp extends StatelessWidget {
  const KidzKanklaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KidzKanklai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textTheme: GoogleFonts.kanitTextTheme(),
        useMaterial3: true,
      ),

      // ลงทะเบียน Observer ของเรา
      navigatorObservers: [musicObserver],

      home: const LoadingScreen(),

      routes: {
        // ... routes ...
        '/auth': (context) => const AuthGate(),
        '/me': (context) => const MeScreen(),

        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgotpw': (context) => const ForgotPWScreen(),
        '/resetpw': (context) => const ResetPWScreen(),
        '/lobby': (context) => LobbyScreen(),
        '/fashion': (context) => const FashionPage(), // Add Fashion Route
        '/setting': (context) => const SettingScreen(),
        '/allquest': (context) => const AllQuestScreen(),
        '/createnormalquest': (context) => CreateNormalQuestScreen(
          onSubmit: (data) {
            // ปริ้นท์เช็คเฉยๆ ว่าได้ข้อมูลกลับมาไหม (เอาไว้เช็คตอน Debug)
            print('✅ สร้างเควสสำเร็จและกลับมาที่เมนเมนูแล้ว');
            print('Quest Name: ${data['name']}');

          },
        ),
        '/questdetail': (context) => const QuestDetailScreen(),
        '/countdown': (context) => const CountdownQuestScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/notification': (context) => const NotificationScreen(),
        '/achievement': (context) => const AchievementScreen(),
        '/lootbox': (context) => const LootboxScreen(),
        '/map': (context) => const MapScreen(),
        '/gasha': (context) => const GashaScreen(),
        '/club': (context) => const ClubScreen(),
        '/createclubquest': (context) => CreateClubQuestScreen(
          onSubmit: (data) {
            // บันทึกข้อมูลภารกิจ
            print('Quest Name: ${data['name']}');
            print('Quest Detail: ${data['detail']}');
            print('Due Date: ${data['date']}');
            print('Has Image: ${data['hasImage']}');

            // TODO: บันทึกลง database
            // await questService.createQuest(data);

            // กลับหน้าเดิม
            Navigator.pop(context);

            // แสดงข้อความสำเร็จ
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('สร้างภารกิจสำเร็จ!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
        '/startgame': (context) => const StartGameScreen(),
        '/load': (context) => const LoadingScreen(),
      },
    );
  }
}

/// 🔐 ตัวคุมว่า login แล้วหรือยัง
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          // ✅ login แล้ว
          AudioManager().playBGM('lobby.mp3');
          return const LobbyScreen();
        } else {
          // ❌ ยังไม่ login
          return const LoginScreen();
        }
      },
    );
  }
}
