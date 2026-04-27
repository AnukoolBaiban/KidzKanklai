import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioManager {
  // 1. ทำเป็น Singleton เพื่อให้เรียกใช้ได้จากทุกหน้า
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  // 2. ตัวเล่นเสียง
  final AudioPlayer _musicPlayer = AudioPlayer(); // สำหรับ BGM
  final AudioPlayer _sfxPlayer = AudioPlayer(); // สำหรับ SFX

  // 3. ค่า Config เริ่มต้น
  double _musicVolume = 0.7;
  double _sfxVolume = 0.7;
  bool _isMuted = false;

  // Getter เอาไว้ดึงค่าไปโชว์ใน UI
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get isMuted => _isMuted;

  // 4. เริ่มต้นโหลดค่า (ควรเรียกตอนเปิดแอป)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _musicVolume = prefs.getDouble('musicVolume') ?? 0.7;
    _sfxVolume = prefs.getDouble('sfxVolume') ?? 0.7;
    _isMuted = prefs.getBool('isMuted') ?? false;

    // ตั้งค่าเริ่มต้นให้ Player
    await _updatePlayersVolume();

    // ตั้งค่า Mode ให้เล่นทับกันได้ (Low Latency)
    await _musicPlayer.setReleaseMode(ReleaseMode.loop); // BGM วนซ้ำ
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
  }

  // เพิ่มตัวแปรเก็บชื่อเพลงที่กำลังเล่นอยู่
  String? _currentBGM;

  // 5. ฟังก์ชันเล่นเพลง BGM (ฉบับอัปเดต)
  Future<void> playBGM(String fileName) async {
    // ถ้าไฟล์ที่จะเล่น เป็นไฟล์เดียวกับที่กำลังเล่นอยู่ ให้ข้ามคำสั่งไปเลย เพลงจะได้เล่นต่อเนื่อง
    if (_currentBGM == fileName) return;

    _currentBGM = fileName; // อัปเดตชื่อเพลงปัจจุบัน
    await _musicPlayer.play(AssetSource('audio/$fileName'));
  }

  // 6. ฟังก์ชันเล่น SFX
  Future<void> playSFX(String fileName) async {
    if (_isMuted) return; // ถ้า Mute อยู่ ไม่ต้องเล่น SFX
    // สร้าง Player ใหม่ชั่วคราวสำหรับ SFX ที่อาจเกิดซ้อนกัน หรือใช้ player เดียวก็ได้
    await _sfxPlayer.play(AssetSource('audio/$fileName'), volume: _sfxVolume);
  }

  // 7. ฟังก์ชันปรับระดับเสียง Music
  Future<void> setMusicVolume(double value) async {
    _musicVolume = value;
    await _updatePlayersVolume();
    _saveSettings();
  }

  // 8. ฟังก์ชันปรับระดับเสียง SFX
  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value;
    // SFX ปกติจะดังตอนเล่นเลย ไม่ต้อง set ค้างไว้เหมือน BGM แต่เก็บค่าไว้ใช้ตอน play
    _saveSettings();
  }

  // 9. ฟังก์ชัน Toggle Mute
  Future<void> toggleMute(bool mute) async {
    _isMuted = mute;
    await _updatePlayersVolume();
    _saveSettings();
  }

  // อัปเดตเสียงจริงไปที่ Player
  Future<void> _updatePlayersVolume() async {
    if (_isMuted) {
      await _musicPlayer.setVolume(0);
      // SFX ไม่ต้อง set เพราะเช็คตอนกดเล่น
    } else {
      await _musicPlayer.setVolume(_musicVolume);
    }
  }

  // บันทึกลงเครื่อง
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('musicVolume', _musicVolume);
    await prefs.setDouble('sfxVolume', _sfxVolume);
    await prefs.setBool('isMuted', _isMuted);
  }
}

class MusicRouteObserver extends NavigatorObserver {
  // 1. สร้าง Stack เพื่อเก็บประวัติเพลงของแต่ละหน้า
  final List<String> _musicHistory = [];

  // ฟังก์ชันสำหรับเช็คว่าแต่ละหน้าควรใช้เพลงอะไร
  String? _getMusicForRoute(String? routeName) {
    switch (routeName) {
      case '/lobby':
      case '/achievement':
        return 'lobby.mp3';
      case '/profile':
        return 'profile.mp3';
      case '/all_quest':
      case '/allquest':
      case '/createnormalquest':
      case '/questdetail':
      case '/countdown':
        return 'quest.mp3';
      case '/map':
        return 'map.mp3';
      case '/fashion':
        return 'fashion.mp3';
      case '/gacha':
      case '/gasha':
        return 'gacha.mp3';
      case '/club':
      case '/club-create':
      case '/createclubquest':
      case '/clubquestdetail':
      case '/clubroom':
        return 'club.mp3';
      default:
        return null;
    }
  }

  // ฟังก์ชันดึงชื่อหน้าจอ (รองรับกรณี MaterialPageRoute ไม่ได้ระบุชื่อ)
  String? _extractRouteName(Route<dynamic>? route) {
    if (route == null) return null;
    
    // 1. ใช้ชื่อจาก settings.name (จากการใช้ Navigator.pushNamed)
    if (route.settings.name != null) {
      return route.settings.name;
    }
    
    // 2. กรณีไม่มีชื่อ (จากการใช้ Navigator.push + MaterialPageRoute)
    // ให้ใช้การตรวจสอบจาก runtimeType ของ builder
    if (route is MaterialPageRoute) {
      final builderStr = route.builder.runtimeType.toString();
      if (builderStr.contains('LobbyScreen')) return '/lobby';
      if (builderStr.contains('Quest') || builderStr.contains('Countdown')) return '/all_quest';
      if (builderStr.contains('Club')) return '/club';
      if (builderStr.contains('Achievement')) return '/achievement';
      if (builderStr.contains('Map') || builderStr.contains('LocationUpgrade')) return '/map';
      if (builderStr.contains('Fashion')) return '/fashion';
      if (builderStr.contains('Gasha') || builderStr.contains('Gacha')) return '/gacha';
      if (builderStr.contains('Profile')) return '/profile';
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    
    final routeName = _extractRouteName(route);
    final newMusic = _getMusicForRoute(routeName);

    if (newMusic != null) {
      // ถ้าหน้านี้มีเพลงเฉพาะของมัน ให้บันทึกลงประวัติและเล่นเพลงนั้น
      _musicHistory.add(newMusic);
      AudioManager().playBGM(newMusic);
    } else {
      // ถ้าหน้าใหม่ไม่มีชื่อ route ชัดเจน (เช่น Dialog)
      // ให้คัดลอกเพลงล่าสุดใส่ประวัติเพิ่มไป เพื่อให้ตอนกดย้อนกลับ (Pop) ลบออกได้อย่างถูกต้อง
      if (_musicHistory.isNotEmpty) {
        _musicHistory.add(_musicHistory.last);
      } else {
        _musicHistory.add('lobby.mp3');
        AudioManager().playBGM('lobby.mp3');
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    
    // เมื่อกดย้อนกลับ ให้ลบเพลงของหน้าปัจจุบันที่กำลังจะปิด ออกจากประวัติ
    if (_musicHistory.isNotEmpty) {
      _musicHistory.removeLast();
    }

    // 1. ตรวจสอบชื่อ Route ของหน้าที่เรากำลังจะย้อนกลับไปแบบเจาะลึก
    final routeName = _extractRouteName(previousRoute);
    final explicitMusic = _getMusicForRoute(routeName);

    if (explicitMusic != null) {
      AudioManager().playBGM(explicitMusic);
      if (_musicHistory.isNotEmpty) {
        _musicHistory[_musicHistory.length - 1] = explicitMusic;
      } else {
        _musicHistory.add(explicitMusic);
      }
    } else {
      if (_musicHistory.isNotEmpty) {
        AudioManager().playBGM(_musicHistory.last);
      } else {
        AudioManager().playBGM('lobby.mp3');
      }
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    
    if (_musicHistory.isNotEmpty) {
      _musicHistory.removeLast();
    }

    final routeName = _extractRouteName(newRoute);
    final newMusic = _getMusicForRoute(routeName);

    if (newMusic != null) {
      _musicHistory.add(newMusic);
      AudioManager().playBGM(newMusic);
    } else {
      if (_musicHistory.isNotEmpty) {
        _musicHistory.add(_musicHistory.last);
        AudioManager().playBGM(_musicHistory.last);
      } else {
        _musicHistory.add('lobby.mp3');
        AudioManager().playBGM('lobby.mp3');
      }
    }
  }
}
