import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_application_1/services/audio_manager.dart';

/// รายการเพลงที่มีในแอป
class MusicTrack {
  final String displayName;
  final String assetPath;

  const MusicTrack({required this.displayName, required this.assetPath});
}

const List<MusicTrack> _allTracks = [
  MusicTrack(displayName: 'ร่าเริง', assetPath: 'audio/lobby.mp3'),
  MusicTrack(displayName: 'คาเฟ่', assetPath: 'audio/map.mp3'),
  MusicTrack(displayName: 'ดำเนินการ', assetPath: 'audio/quest.mp3'),
  MusicTrack(displayName: 'เพลิดเพลิน', assetPath: 'audio/profile.mp3'),
  MusicTrack(displayName: 'เรียบง่าย', assetPath: 'audio/fashion.mp3'),
  MusicTrack(displayName: 'น่ารัก', assetPath: 'audio/club.mp3'),
  MusicTrack(displayName: 'เร้าใจ', assetPath: 'audio/gacha.mp3'),
];

class MusicSelectPopup extends StatefulWidget {
  /// เพลงที่กำลังเล่นอยู่ตอนนี้ (null = ไม่มีเพลง)
  final String? currentTrackPath;
  final AudioPlayer audioPlayer;
  final Function(String?) onSelect;

  const MusicSelectPopup({
    super.key,
    required this.audioPlayer,
    required this.onSelect,
    this.currentTrackPath,
  });

  /// แสดง popup เลือกเพลง
  static Future<String?> show(
    BuildContext context, {
    required AudioPlayer audioPlayer,
    String? currentTrackPath,
    required Function(String?) onSelect,
  }) {
    return showDialog<String?>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => MusicSelectPopup(
        audioPlayer: audioPlayer,
        currentTrackPath: currentTrackPath,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<MusicSelectPopup> createState() => _MusicSelectPopupState();
}

class _MusicSelectPopupState extends State<MusicSelectPopup> {
  String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _selectedPath = widget.currentTrackPath;
  }

  Future<void> _handleSelect(String? assetPath) async {
    setState(() {
      _selectedPath = assetPath;
    });
    await widget.onSelect(assetPath);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: Center(
        child: Container(
          width: size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ── Background Split (เดียวกับ GashaRatePopup) ──
              Positioned.fill(
                child: Column(
                  children: [
                    Container(
                      height: 65,
                      color: const Color(0xFF9DD0E7),
                    ),
                    Expanded(
                      child: Container(color: const Color(0xFFC6F4FF)),
                    ),
                  ],
                ),
              ),

              // ── Content ──
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  SizedBox(
                    height: 65,
                    child: Stack(
                      children: [
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/button/music-note1.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.music_note, color: Color(0xFF002A50), size: 24),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'เลือกเพลง',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF002A50),
                                  shadows: [
                                    Shadow(color: Colors.white, offset: Offset(1.5, 1.5), blurRadius: 1),
                                    Shadow(color: Colors.white, offset: Offset(-1.5, -1.5), blurRadius: 1),
                                    Shadow(color: Colors.white, offset: Offset(1.5, -1.5), blurRadius: 1),
                                    Shadow(color: Colors.white, offset: Offset(-1.5, 1.5), blurRadius: 1),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ปุ่มปิด X
                        Positioned(
                          right: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context, _selectedPath),
                              child: const Icon(Icons.close, color: Colors.white, size: 30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // กล่องสีขาวรายการเพลง
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ตัวเลือก "ไม่มีเพลง"
                          _buildTrackRow(
                            label: '🔇 ปิดเสียงเพลง',
                            assetPath: null,
                            isSelected: _selectedPath == null,
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          // รายการเพลงทั้งหมด
                          Flexible(
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(scrollbars: false),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _allTracks.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, indent: 16, endIndent: 16),
                                itemBuilder: (context, index) {
                                  final track = _allTracks[index];
                                  return _buildTrackRow(
                                    label: track.displayName,
                                    assetPath: track.assetPath,
                                    isSelected: _selectedPath == track.assetPath,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackRow({
    required String label,
    required String? assetPath,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _handleSelect(assetPath),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const SizedBox(width: 8), 
            // ชื่อเพลง
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF2374B5) : const Color(0xFF333333),
                ),
              ),
            ),

            // checkmark ถ้าเป็นเพลงที่เลือกอยู่
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 24),
          ],
        ),
      ),
    );
  }
}
