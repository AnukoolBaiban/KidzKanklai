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
  final AudioPlayer _sfxPlayer = AudioPlayer();   // สำหรับ SFX

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
  // ฟังก์ชันส่วนกลางสำหรับเช็คว่าควรเล่นเพลงอะไร
  void _updateMusic(Route<dynamic>? route) {
    // ดึงชื่อหน้าจอออกมา
    final routeName = route?.settings.name;

    // เทียบชื่อหน้าจอแล้วสั่งเล่นเพลงที่ต้องการเลย!
    if (routeName == '/lobby') {
      AudioManager().playBGM('lobby.mp3');
    } else if (routeName == '/profile') {
      AudioManager().playBGM('profile.mp3');
    } 
    // ถ้าหน้าไหนไม่มีเพลงเฉพาะ จะปล่อยให้เล่นเพลงเดิมต่อไป หรือจะสั่ง pause() ก็ได้
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // เมื่อเปิดหน้าใหม่ ให้เช็คว่าต้องเปลี่ยนเพลงไหม
    _updateMusic(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // เมื่อกดย้อนกลับ ให้เช็คเพลงของหน้าจอ "ที่กำลังจะกลับไปแสดง (previousRoute)"
    _updateMusic(previousRoute);
  }
}