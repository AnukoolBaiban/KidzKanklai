// ไฟล์: lib/screens/character_widget.dart
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:provider/provider.dart';
import '../config/rive_cache.dart';           // เช็ค path ให้ถูก
import '../config/user_pose_provider.dart'; // เช็ค path ให้ถูก

import '../api_service.dart'; // Import User model

class CharacterWidget extends StatefulWidget {
  final double height;
  final double width;
  final User? user; // Accept User object

  const CharacterWidget({
    super.key, 
    this.height = 500, 
    this.width = 400,
    this.user,
  });

  @override
  State<CharacterWidget> createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget> {
  StateMachineController? _controller;
  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMITrigger? _tapInput;
  SMINumber? _skinInput;
  SMINumber? _faceInput;
  SMINumber? _clothInput;
  bool _isRiveLoaded = false;

  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (controller == null && artboard.stateMachines.isNotEmpty) {
       controller = StateMachineController.fromArtboard(artboard, artboard.stateMachines.first.name);
    }

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;

      _poseInput = controller.findInput<SMINumber>('Pose') as SMINumber?;
      
      // Exact match for HairID
      var hairInputRaw = controller.inputs.firstWhere((e) => e.name == 'HairID', orElse: () => controller!.inputs.first);
      if (hairInputRaw is SMINumber && hairInputRaw.name == 'HairID') {
          _hairInput = hairInputRaw;
      }

      // Exact match for Tapcharacter
      var tapInputRaw = controller.inputs.firstWhere((e) => e.name == 'Tapcharacter', orElse: () => controller!.inputs.first);
      if (tapInputRaw is SMITrigger && tapInputRaw.name == 'Tapcharacter') {
          _tapInput = tapInputRaw;
      }
      
      // Bind other inputs
      var faceInputRaw = controller.inputs.firstWhere((e) => e.name == 'FaceID', orElse: () => controller!.inputs.first);
      if (faceInputRaw is SMINumber && faceInputRaw.name == 'FaceID') _faceInput = faceInputRaw;

      var skinInputRaw = controller.inputs.firstWhere((e) => e.name == 'SkinID', orElse: () => controller!.inputs.first);
      if (skinInputRaw is SMINumber && skinInputRaw.name == 'SkinID') _skinInput = skinInputRaw;

      var clothInputRaw = controller.inputs.firstWhere((e) => e.name == 'ClothID' || e.name == 'BodyID', orElse: () => controller!.inputs.first);
      if (clothInputRaw is SMINumber && (clothInputRaw.name == 'ClothID' || clothInputRaw.name == 'BodyID')) _clothInput = clothInputRaw;

      // Apply initial state if available
      _updateRiveInputs();
    }
    
    if (mounted) setState(() => _isRiveLoaded = true);
  }

  void _updateRiveInputs() {
      if (widget.user == null) return;
      
      // Helper to parse ID
      double parseId(String s) {
          if (s.isEmpty) return 0;
          if (s.contains('_')) {
             try { return double.parse(s.split('_').last); } catch (_) {}
          }
          if (s.startsWith("Hair Style ")) {
             try { return double.parse(s.replaceAll("Hair Style ", "")); } catch (_) {}
          }
          try { return double.parse(s); } catch(_) { return 0; }
      }

      if (_hairInput != null) _hairInput!.value = parseId(widget.user!.equippedHair);
      if (_faceInput != null) _faceInput!.value = parseId(widget.user!.equippedFace);
      if (_skinInput != null) _skinInput!.value = parseId(widget.user!.equippedSkin);
      if (_clothInput != null) _clothInput!.value = parseId(widget.user!.equippedCloth); // Also handles Body/Shoes if logic allows
  }

  @override
  Widget build(BuildContext context) {
    // 2. ดึงค่า Emotion จาก Provider มาใส่ Rive Input 'Pose'
    final emotionIndex = context.select<UserPoseProvider, double>((p) => p.currentEmotion);
    if (_poseInput != null && _poseInput!.value != emotionIndex) {
       _poseInput!.value = emotionIndex;
    }

    // 3. ตรวจสอบ Trigger Reaction
    final shouldTrigger = context.select<UserPoseProvider, bool>((p) => p.shouldTriggerReaction);
    if (shouldTrigger && _tapInput != null) {
       _tapInput!.fire();
    }

    // 4. Update Inputs from User (Reactive)
    _updateRiveInputs();

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Stack(
        alignment: Alignment.center,
        children: [
           // Loading Indicator
           if (!_isRiveLoaded) const CircularProgressIndicator(),

           // Rive Animation Logic
           if (RiveCache().file != null) 
             RiveAnimation.direct(
                RiveCache().file!,
                fit: BoxFit.contain,
                antialiasing: false,
                onInit: _onRiveInit,
                stateMachines: const ['State Machine 1'],
             )
           else 
             RiveAnimation.asset(
                'assets/animation/Model2.0.riv', 
                fit: BoxFit.contain,
                antialiasing: false, 
                onInit: _onRiveInit,
             ),
             
           // Tap Area -> Trigger Reaction
           Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  context.read<UserPoseProvider>().triggerReaction();
                },
               behavior: HitTestBehavior.translucent,
               child: Container(color: Colors.transparent),
             ),
           ),
        ],
      ),
    );
  }
}