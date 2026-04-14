// ไฟล์: lib/utils/rive_cache.dart
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class RiveCache {
  static final RiveCache _instance = RiveCache._internal();
  factory RiveCache() => _instance;
  RiveCache._internal();

  final Map<String, RiveFile> _files = {};
  bool _isLoading = false;

  /// เรียกใช้ฟังก์ชันนี้ที่ main.dart เพื่อโหลดโมเดลรอไว้ก่อน
  Future<void> loadAssets(List<String> assetPaths) async {
    if (_isLoading) return;

    _isLoading = true;
    try {
      await RiveFile.initialize(); // สำคัญมาก
      for (final path in assetPaths) {
        if (!_files.containsKey(path)) {
          print("RiveCache: Start loading $path...");
          final data = await rootBundle.load(path);
          _files[path] = RiveFile.import(data);
          print("RiveCache: Successfully loaded Rive file $path !");
        }
      }
    } catch (e) {
      print("RiveCache: Error loading file: $e");
    } finally {
      _isLoading = false;
    }
  }

  RiveFile? getFile(String assetPath) => _files[assetPath];
}