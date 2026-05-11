import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioManager with WidgetsBindingObserver {
  // 1. ทำเป็น Singleton เพื่อให้เรียกใช้ได้จากทุกหน้า
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  // 2. ตัวเล่นเสียง — BGM ใช้ player เดียว loop ตลอด
  //    SFX & Button ใช้ player ชั่วคราว (สร้างใหม่ทุกครั้ง) เพื่อไม่ให้ชิง session กับ BGM
  final AudioPlayer _musicPlayer = AudioPlayer(); // สำหรับ BGM
  late final AudioContext _audioCtx; // เก็บ context ไว้ใช้กับ SFX player ชั่วคราว

  // 3. ค่า Config เริ่มต้น
  double _musicVolume = 0.7;
  double _sfxVolume = 0.7;
  bool _isMuted = false;

  // Getter เอาไว้ดึงค่าไปโชว์ใน UI
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get isMuted => _isMuted;

  // เพิ่มตัวแปรเก็บชื่อเพลงที่กำลังเล่นอยู่
  String? _currentBGM;

  // 4. เริ่มต้นโหลดค่า (ควรเรียกตอนเปิดแอป)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _musicVolume = prefs.getDouble('musicVolume') ?? 0.7;
    _sfxVolume = prefs.getDouble('sfxVolume') ?? 0.7;
    _isMuted = prefs.getBool('isMuted') ?? false;

    // ─── ตั้ง AudioContext ระดับ Global ให้ "ผสมเสียง" ได้ ──────────────────
    // บน iOS → mixWithOthers + duckOthers: ลดเสียงอื่นเบาลงชั่วคราวแทนการหยุด
    // บน Android → audioFocus = none → ไม่แย่ง focus จากเสียงอื่น
    final ctx = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.duckOthers,
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        audioMode: AndroidAudioMode.normal,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
    );
    AudioPlayer.global.setAudioContext(ctx);
    _audioCtx = ctx;

    // ─── ตั้งค่าเริ่มต้นให้ BGM Player ────────────────────────────────────────
    await _musicPlayer.setAudioContext(ctx);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop); // BGM วนซ้ำ
    await _updatePlayersVolume();

    // ลงทะเบียน lifecycle observer เพื่อจัดการเพลงตอนกด Home / ออกแอป
    WidgetsBinding.instance.addObserver(this);
  }

  // 5. ฟังก์ชันเล่นเพลง BGM (ฉบับอัปเดต)
  Future<void> playBGM(String fileName) async {
    // ถ้าไฟล์ที่จะเล่น เป็นไฟล์เดียวกับที่กำลังเล่นอยู่ ให้ข้ามคำสั่งไปเลย เพลงจะได้เล่นต่อเนื่อง
    if (_currentBGM == fileName) return;

    // stop เพลงเก่าก่อนเสมอ เพื่อไม่ให้เพลงเล่นซ้อนกัน
    await _musicPlayer.stop();

    _currentBGM = fileName; // อัปเดตชื่อเพลงปัจจุบัน
    await _musicPlayer.play(AssetSource('audio/$fileName'));
  }

  // ฟังก์ชันหยุดเพลง BGM (ใช้สำหรับหน้าที่ต้องเงียบ เช่น loading)
  Future<void> stopBGM() async {
    _currentBGM = null;
    await _musicPlayer.stop();
  }

  // 6. ฟังก์ชันเล่น SFX — สร้าง player ชั่วคราวทุกครั้ง แล้ว dispose หลังเล่นจบ
  //    ทำให้ SFX ไม่มีทางไป interrupt session ของ BGM
  Future<void> playSFX(String fileName) async {
    if (_isMuted) return;
    final player = AudioPlayer();
    await player.setAudioContext(_audioCtx);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.play(AssetSource('audio/$fileName'), volume: _sfxVolume);
    player.onPlayerComplete.listen((_) => player.dispose());
  }

  // 6.1 ฟังก์ชันเล่นเสียงปุ่ม (Button Sound) — เรียกใช้ได้จากทุกที่ในแอป
  /// สร้าง player ชั่วคราวเช่นเดียวกับ SFX เพื่อไม่ให้ชิง audio session กับ BGM
  Future<void> playButtonSound() async {
    if (_isMuted) return;
    final player = AudioPlayer();
    await player.setAudioContext(_audioCtx);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.play(
      AssetSource('audio/button_sound.MP3'),
      volume: _sfxVolume,
    );
    player.onPlayerComplete.listen((_) => player.dispose());
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

  // ─── Lifecycle Handler ────────────────────────────────────────────────────
  // จัดการเพลงเมื่อกด Home หรือออกจากแอป (ผ่าน WidgetsBindingObserver)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // กด Home / ออกแอป → หยุดเพลงทันที
        _musicPlayer.stop();
        break;
      case AppLifecycleState.resumed:
        // กลับเข้าแอป → เล่นเพลงต่อจากหน้าที่ค้างอยู่
        if (_currentBGM != null && !_isMuted) {
          _musicPlayer.play(AssetSource('audio/$_currentBGM'));
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  // ล้าง observer เมื่อไม่ใช้งาน
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _musicPlayer.dispose();
  }
}

// ─── AppSoundLayer ─────────────────────────────────────────────────────────────
// Widget ดักจับการกดทุกจุดในแอปโดยอัตโนมัติ ไม่ต้องแก้ไขแต่ละหน้า
//
// วิธีใช้ — เพิ่มใน MaterialApp.builder ครั้งเดียว:
//
//   MaterialApp(
//     builder: (context, child) => AppSoundLayer(child: child!),
//     ...
//   )
//
// หลักการทำงาน:
//   - Listener.onPointerDown  → บันทึกตำแหน่ง pointer ลง
//   - Listener.onPointerUp    → ถ้า pointer เคลื่อนน้อยกว่า 10px (คือ tap ไม่ใช่ scroll)
//                               → เล่นเสียงปุ่ม
//   ดังนั้นการ scroll จะไม่เล่นเสียง แต่การกดปุ่มทุกชนิดจะเล่นเสียง

class AppSoundLayer extends StatefulWidget {
  final Widget child;

  const AppSoundLayer({super.key, required this.child});

  @override
  State<AppSoundLayer> createState() => _AppSoundLayerState();
}

class _AppSoundLayerState extends State<AppSoundLayer> {
  // เก็บตำแหน่งที่นิ้วแตะหน้าจอครั้งแรก
  Offset? _pointerDownPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // HitTestBehavior.translucent = ให้ทุก widget ด้านล่างยังรับ event ได้ตามปกติ
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        _pointerDownPosition = event.position;
      },
      onPointerUp: (PointerUpEvent event) {
        if (_pointerDownPosition == null) return;

        // คำนวณระยะทางที่นิ้วเคลื่อนไป
        final distance = (event.position - _pointerDownPosition!).distance;

        // ถ้าน้อยกว่า 10px → ถือว่าเป็น "tap" แล้วเล่นเสียงปุ่ม
        // ถ้ามากกว่า → ถือว่าเป็น scroll/drag ไม่เล่นเสียง
        if (distance < 10.0) {
          AudioManager().playButtonSound();
        }

        _pointerDownPosition = null;
      },
      onPointerCancel: (_) {
        // ยกเลิก gesture (เช่น เลื่อนออกนอกจอ) → reset ไม่เล่นเสียง
        _pointerDownPosition = null;
      },
      child: widget.child,
    );
  }
}

// ─── Route Music Observer ─────────────────────────────────────────────────────

// ค่าพิเศษสำหรับหน้าที่ต้อง "เงียบ" (ไม่มีเพลง เช่น loading screen)
const String _kSilent = '__SILENT__';

// TODO: เมื่อมีไฟล์เพลงพร้อมแล้ว ให้ทำ 2 ขั้นตอน:
//   1. วางไฟล์ .mp3 ไว้ที่ → assets/audio/<ชื่อไฟล์>.mp3
//   2. แก้ชื่อไฟล์ด้านล่างให้ตรงกับไฟล์จริง
// ทุกหน้าใน group (startgame, login, register, forgotpw, resetpw) ใช้เพลงเดียวกัน
// เมื่อออกจาก group เพลงจะหยุดอัตโนมัติ
const String _kMenuMusic = 'menu.mp3'; // ← แก้ชื่อไฟล์ตรงนี้จุดเดียว

class MusicRouteObserver extends NavigatorObserver {
  // 1. สร้าง Stack เพื่อเก็บประวัติเพลงของแต่ละหน้า
  final List<String> _musicHistory = [];

  // ฟังก์ชันสำหรับเช็คว่าแต่ละหน้าควรใช้เพลงอะไร
  /// คืนค่า:
  ///   - ชื่อไฟล์ mp3  → เล่นเพลงนั้น
  ///   - _kSilent       → หยุดเพลง (หน้า login / loading ฯลฯ)
  ///   - null           → ไม่รู้จัก route → สืบทอดเพลงจากหน้าก่อน (เช่น Dialog)
  String? _getMusicForRoute(String? routeName) {
    switch (routeName) {
      // หน้าที่ต้องเงียบสนิท (ยังไม่มีเพลง) ──────────────────────────────────
      case '/':
      case '/load':
      case '/auth':
      case '/me':
      case '/video':
      case '/countdown':
        return _kSilent;

      // หน้า Menu/Login group (ใช้เพลงเดียวกัน รอใส่ไฟล์เพลงภายหลัง) ──────────
      // TODO: เมื่อมีไฟล์เพลงพร้อม แก้ค่า _kMenuMusic ด้านบนได้เลย
      case '/startgame':
      case '/login':
      case '/register':
      case '/forgotpw':
      case '/resetpw':
        return _kMenuMusic;

      // หน้าที่มีเพลงเฉพาะ ──────────────────────────────────────────────────
      case '/lobby':
      case '/achievement':
        return 'lobby.mp3';
      case '/profile':
        return 'profile.mp3';
      case '/all_quest':
      case '/allquest':
      case '/createnormalquest':
      case '/questdetail':
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
        return null; // ไม่รู้จัก → สืบทอดเพลงปัจจุบัน
    }
  }

  // ฟังก์ชันดึงชื่อหน้าจอ (รองรับกรณี MaterialPageRoute ไม่ได้ระบุชื่อ)
  String? _extractRouteName(Route<dynamic>? route) {
    if (route == null) return null;

    // 1. ใช้ชื่อจาก settings.name (จากการใช้ Navigator.pushNamed)
    if (route.settings.name != null) return route.settings.name;

    // 2. กรณีไม่มีชื่อ (จากการใช้ Navigator.push + MaterialPageRoute)
    // ให้ใช้การตรวจสอบจาก runtimeType ของ builder
    if (route is MaterialPageRoute) {
      final s = route.builder.runtimeType.toString();
      if (s.contains('LobbyScreen')) return '/lobby';
      if (s.contains('Club')) return '/club';
      if (s.contains('Countdown')) return '/countdown';
      if (s.contains('Quest')) return '/all_quest';
      if (s.contains('Achievement')) return '/achievement';
      if (s.contains('Map') || s.contains('LocationUpgrade')) return '/map';
      if (s.contains('Fashion')) return '/fashion';
      if (s.contains('Gasha') || s.contains('Gacha')) return '/gacha';
      if (s.contains('Profile')) return '/profile';
      if (s.contains('Login')) return '/login';
      if (s.contains('Register')) return '/register';
      if (s.contains('Loading')) return '/load';
      if (s.contains('VideoTransition')) return '/video';
      if (s.contains('StartGame')) return '/startgame';
    }
    return null;
  }

  // ฟังก์ชัน apply เพลง ใช้ร่วมกันทุก event เพื่อไม่ให้โค้ดซ้ำ
  void _applyMusic(String? musicKey) {
    if (musicKey == null) return; // ไม่รู้จัก route → ไม่ทำอะไร
    if (musicKey == _kSilent) {
      AudioManager().stopBGM(); // หน้าเงียบ → หยุดเพลง
    } else {
      AudioManager().playBGM(musicKey); // หน้ามีเพลง → เล่น
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    final routeName = _extractRouteName(route);
    final music = _getMusicForRoute(routeName);

    if (music != null) {
      // ถ้าหน้านี้มีเพลงเฉพาะของมัน (หรือเงียบ) ให้บันทึกลงประวัติและ apply
      _musicHistory.add(music);
      _applyMusic(music);
    } else {
      // ถ้าหน้าใหม่ไม่มีชื่อ route ชัดเจน (เช่น Dialog)
      // ให้คัดลอกเพลงล่าสุดใส่ประวัติเพิ่มไป เพื่อให้ตอนกดย้อนกลับ (Pop) ลบออกได้อย่างถูกต้อง
      // ถ้า history ว่าง (เช่น เปิดแอปครั้งแรก) ให้เงียบแทนการเล่น lobby.mp3 อัตโนมัติ
      final inherited = _musicHistory.isNotEmpty ? _musicHistory.last : _kSilent;
      _musicHistory.add(inherited);
      // ไม่ต้อง applyMusic เพราะเพลงเดิมก็กำลังเล่นอยู่แล้ว
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    // เมื่อกดย้อนกลับ ให้ลบเพลงของหน้าปัจจุบันที่กำลังจะปิด ออกจากประวัติ
    if (_musicHistory.isNotEmpty) _musicHistory.removeLast();

    // ตรวจสอบชื่อ Route ของหน้าที่เรากำลังจะย้อนกลับไปแบบเจาะลึก
    final routeName = _extractRouteName(previousRoute);
    final explicitMusic = _getMusicForRoute(routeName);

    if (explicitMusic != null) {
      // หน้าที่กลับไปมี mapping ชัดเจน → ใช้ค่านั้น และอัปเดต history ด้วย
      if (_musicHistory.isNotEmpty) {
        _musicHistory[_musicHistory.length - 1] = explicitMusic;
      } else {
        _musicHistory.add(explicitMusic);
      }
      _applyMusic(explicitMusic);
    } else {
      // ไม่รู้จัก → ใช้ history ล่าสุด
      final fallback = _musicHistory.isNotEmpty ? _musicHistory.last : _kSilent;
      _applyMusic(fallback);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    // เมื่อใช้ pushReplacementNamed ให้ลบ history ของหน้าเก่าออกก่อน
    if (_musicHistory.isNotEmpty) _musicHistory.removeLast();

    final routeName = _extractRouteName(newRoute);
    final music = _getMusicForRoute(routeName);

    if (music != null) {
      _musicHistory.add(music);
      // เรียก _applyMusic ซึ่งจะ stop เพลงเก่าก่อนเล่นใหม่เสมอ
      _applyMusic(music);
    } else {
      final inherited = _musicHistory.isNotEmpty ? _musicHistory.last : _kSilent;
      _musicHistory.add(inherited);
    }
  }
}

// ─── Button Sound Widgets ─────────────────────────────────────────────────────
// Widget สำเร็จรูปสำหรับห่อปุ่มต่างๆ ให้เล่นเสียงอัตโนมัติเมื่อกด
// วิธีใช้:
//   SoundButton(onPressed: () { /* your logic */ }, child: Text('กด'))
//   SoundInkWell(onTap: () { /* your logic */ }, child: YourWidget())
//   SoundGestureDetector(onTap: () { /* your logic */ }, child: YourWidget())

/// ห่อ [ElevatedButton] / [TextButton] / [OutlinedButton] / [FilledButton]
/// ให้เล่นเสียงปุ่มอัตโนมัติทุกครั้งที่กด
class SoundButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  /// เลือก variant ของปุ่ม (ค่าเริ่มต้นคือ ElevatedButton)
  final _SoundButtonType type;

  const SoundButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.type = _SoundButtonType.elevated,
  });

  /// ใช้ TextButton
  const SoundButton.text({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : type = _SoundButtonType.text;

  /// ใช้ OutlinedButton
  const SoundButton.outlined({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : type = _SoundButtonType.outlined;

  /// ใช้ FilledButton
  const SoundButton.filled({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : type = _SoundButtonType.filled;

  VoidCallback? get _wrappedOnPressed {
    if (onPressed == null) return null;
    return () {
      AudioManager().playButtonSound();
      onPressed!();
    };
  }

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case _SoundButtonType.text:
        return TextButton(
          onPressed: _wrappedOnPressed,
          style: style,
          child: child,
        );
      case _SoundButtonType.outlined:
        return OutlinedButton(
          onPressed: _wrappedOnPressed,
          style: style,
          child: child,
        );
      case _SoundButtonType.filled:
        return FilledButton(
          onPressed: _wrappedOnPressed,
          style: style,
          child: child,
        );
      case _SoundButtonType.elevated:
        return ElevatedButton(
          onPressed: _wrappedOnPressed,
          style: style,
          child: child,
        );
    }
  }
}

enum _SoundButtonType { elevated, text, outlined, filled }

/// ห่อ widget ใดก็ได้ (เช่น Container, Image, Icon) ให้กดได้และเล่นเสียงปุ่ม
/// แทนที่การใช้ [InkWell] แบบธรรมดา
class SoundInkWell extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;

  const SoundInkWell({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.child,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              AudioManager().playButtonSound();
              onTap!();
            },
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      splashColor: splashColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

/// ห่อ widget ใดก็ได้ด้วย [GestureDetector] ให้เล่นเสียงปุ่มอัตโนมัติเมื่อ onTap
class SoundGestureDetector extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final HitTestBehavior? behavior;

  const SoundGestureDetector({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.child,
    this.behavior,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: onTap == null
          ? null
          : () {
              AudioManager().playButtonSound();
              onTap!();
            },
      onLongPress: onLongPress,
      child: child,
    );
  }
}
