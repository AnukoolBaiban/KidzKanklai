import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image; 

import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart'; 
import 'package:flutter_application_1/widgets/custom_top_bar.dart'; // Import CustomTopBar
import 'package:flutter_application_1/config/rive_cache.dart';

class FashionPage extends StatefulWidget {
  const FashionPage({super.key});

  @override
  State<FashionPage> createState() => _FashionPageState();
}

class _FashionPageState extends State<FashionPage> {
  // --- STATE ---
  String selectedMainTab = FashionData.mainTabs[0]; // เสื้อผ้า, สีผิว, etc.
  String selectedSubTab = FashionData.subTabs[0];   // Cloth, Shoes, etc.
  int selectedItemIndex = 0;
  String selectedAge = 'Kid';
  int selectedSkinColorIndex = 0;
  
  // Data
  List<InventoryItem> _inventory = [];
  List<InventoryItem> _equipped = [];
  bool _isLoading = true;
  User? _user; // Store User profile for TopBar

  // Selection State
  InventoryItem? _selectedItem;

  // Rive Controllers
  SMINumber? _poseInput;
  SMINumber? _hairInput; 
  SMINumber? _faceInput;
  SMINumber? _skinInput;
  SMINumber? _bodyInput; // Cloth uses BodyID or ClothID? Assuming Body / Cloth logic
  SMINumber? _clothInput;
  
  SMITrigger? _tapInput;
  bool _isRiveLoaded = false;
  StateMachineController? _controller; 
  String _debugInfo = "Initializing..."; // Debug Info State 

  // Navigation State
  final int _selectedIndex = 2; 

  // --- INIT ---
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final inv = await ApiService.getInventory();
    final eq = await ApiService.getEquipped();
    // Also fetch profile for TopBar stats (Coins, etc.)
    final user = await ApiService.getProfile(0); // 0 is ignored as we use token

    if (mounted) {
      setState(() {
        _inventory = inv;
        _equipped = eq;
        _user = user;
        _isLoading = false;
        
        // Sync Rive to Equipped
        _syncRiveToEquipped();
      });
    }
  }

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

  void _syncRiveToEquipped() {
     if (_controller == null) return;
     
     try {
       // 1. Try using User Profile Data (Most Reliable, matches Lobby)
       if (_user != null) {
          if (_hairInput != null) _hairInput!.value = parseId(_user!.equippedHair);
          if (_faceInput != null) _faceInput!.value = parseId(_user!.equippedFace);
          if (_skinInput != null) _skinInput!.value = parseId(_user!.equippedSkin);
          
          // Legacy check: older users might have empty cloth, so we might check body too
          if (_clothInput != null) {
             double val = parseId(_user!.equippedCloth);
             if (val == 0 && _user!.equippedBody.isNotEmpty) val = parseId(_user!.equippedBody);
             _clothInput!.value = val;
          }

          if (mounted) {
           setState(() {
             _debugInfo = "Sync (User Profile):\n"
                          "H: ${_hairInput?.value} (${_user!.equippedHair})\n"
                          "F: ${_faceInput?.value} (${_user!.equippedFace})\n"
                          "S: ${_skinInput?.value}\n"
                          "C: ${_clothInput?.value}";
           });
         }
         return;
       }

       // 2. Fallback: Use Equipped List (If User is null for some reason)
       // Sync Hair
       var hair = _equipped.firstWhere((i) => i.category == 'Hair', orElse: () => InventoryItem(type: '', id: '', category: ''));
       if (_hairInput != null && hair.id.isNotEmpty) {
          _hairInput!.value = hair.riveId.toDouble();
       }
       
       // Sync Face
       var face = _equipped.firstWhere((i) => i.category == 'Face', orElse: () => InventoryItem(type: '', id: '', category: ''));
       if (_faceInput != null && face.id.isNotEmpty) {
          _faceInput!.value = face.riveId.toDouble();
       }

       // Sync Skin
       var skin = _equipped.firstWhere((i) => i.category == 'Skin', orElse: () => InventoryItem(type: '', id: '', category: ''));
       if (_skinInput != null && skin.id.isNotEmpty) {
          _skinInput!.value = skin.riveId.toDouble();
       }

       // Sync Cloth
       var cloth = _equipped.firstWhere((i) => i.category == 'Cloth' || i.category == 'Body', orElse: () => InventoryItem(type: '', id: '', category: ''));
       if (_clothInput != null && cloth.id.isNotEmpty) {
          _clothInput!.value = cloth.riveId.toDouble();
       }

       if (mounted) {
         setState(() {
           _debugInfo = "Sync (List Fallback):\n"
                        "H: ${_hairInput?.value}\n"
                        "F: ${_faceInput?.value}\n"
                        "S: ${_skinInput?.value}\n"
                        "C: ${_clothInput?.value}";
         });
       }

     } catch (e) {
       print("Error syncing Rive: $e");
       setState(() => _debugInfo = "Sync Error: $e");
     }
  }
  
  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (controller == null && artboard.stateMachines.isNotEmpty) {
       controller = StateMachineController.fromArtboard(artboard, artboard.stateMachines.first.name);
    }

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;
      
      // Auto-bind inputs
      print("--- [DEBUG] Rive Inputs for Model2.0.riv ---");
      for (var input in controller.inputs) {
        print("Input Name: '${input.name}' | Type: ${input.runtimeType}");
        
        if (input.name == 'Pose') _poseInput = input as SMINumber;
        
        if (input.name == 'HairID') _hairInput = input as SMINumber;
        if (input.name == 'FaceID') _faceInput = input as SMINumber;
        if (input.name == 'SkinID') _skinInput = input as SMINumber;
        // Check for common cloth names
        if (input.name == 'ClothID' || input.name == 'BodyID') _clothInput = input as SMINumber;

        // Exact Match for Tapcharacter
        if (input.name == 'Tapcharacter' && input is SMITrigger) {
           _tapInput = input;
        }
      }
      
      _syncRiveToEquipped();
      // Debug info updated in _syncRiveToEquipped
    }
    
    if (mounted) setState(() => _isRiveLoaded = true);
  }

  // --- ACTIONS ---

  void _onMainTabChanged(String tab) {
    setState(() => selectedMainTab = tab);
    if (tab == 'เสื้อผ้า') selectedSubTab = 'Grid'; // Reset to Grid
  }

  void _onSubTabChanged(String tab) {
    setState(() => selectedSubTab = tab);
  }

  Future<void> _onItemSelected(InventoryItem item) async {
    setState(() => _selectedItem = item);
    // Preview in Rive
    print("Selecting Item: ${item.name} (${item.category}) -> RiveID: ${item.riveId}");

    if (item.category == 'Hair' && _hairInput != null) {
       _hairInput!.value = item.riveId.toDouble();
    } else if (item.category == 'Face' && _faceInput != null) {
       _faceInput!.value = item.riveId.toDouble();
    } else if (item.category == 'Skin' && _skinInput != null) {
       _skinInput!.value = item.riveId.toDouble();
    } else if ((item.category == 'Cloth' || item.category == 'Body') && _clothInput != null) {
       _clothInput!.value = item.riveId.toDouble();
    }

    // [AUTO-SAVE] Call API immediately
    final success = await ApiService.equipItem(item.id);
    if (success) {
      if (mounted) {
        // Show subtle feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("สวมใส่ ${item.name} เรียบร้อย"),
            duration: const Duration(milliseconds: 1000), // Short duration
            behavior: SnackBarBehavior.floating, // Floating is less obtrusive
          ),
        );
        
        // Refresh local data to sync everything
        _fetchData(); 
      }
    } else {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เกิดข้อผิดพลาดในการใส่ชุด")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _FashionBackground(),
          
          SafeArea(
            child: Column(
              children: [
                // 1. Custom Top Bar
                CustomTopBar(
                  onNotificationTapped: () => Navigator.pushNamed(context, '/notification'),
                  onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
                ),

                // 2. Main Content (Character + Selection)
                Expanded(
                  child: Column(
                    children: [
                      // Character Area (Preview)
                      Expanded(
                        flex: 4, 
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                             // Rive Character
                             GestureDetector(
                               onTap: () {
                                 if (_tapInput != null) _tapInput!.fire();
                               },
                               child: SizedBox(
                                  height: 400, 
                                  width: 400,
                                  child: (_isLoading || _user == null) 
                                    ? const Center(child: CircularProgressIndicator())
                                    : (RiveCache().file != null 
                                      ? RiveAnimation.direct(
                                          RiveCache().file!,
                                          fit: BoxFit.contain,
                                          onInit: _onRiveInit,
                                          stateMachines: const ['State Machine 1'],
                                        )
                                      : RiveAnimation.asset(
                                          'assets/animation/Model2.0.riv', 
                                          fit: BoxFit.contain,
                                          onInit: _onRiveInit,
                                        )),
                               ),
                             ),
                             
                             // Age/Size Selector
                             Positioned(
                               top: 20,
                               right: 20,
                               child: Column(
                                 children: [
                                   _buildAgeButton(
                                     iconPath: 'assets/images/Fashion/AgeIcon/icon-kid.png',
                                     isSelected: selectedAge == 'Kid',
                                     onTap: () => setState(() => selectedAge = 'Kid'),
                                   ),
                                   const SizedBox(height: 16),
                                   _buildAgeButton(
                                      iconPath: 'assets/images/Fashion/AgeIcon/icon-teen.png',
                                      isSelected: selectedAge == 'Teen',
                                      onTap: () => setState(() => selectedAge = 'Teen'),
                                   ),
                                   const SizedBox(height: 16),
                                   _buildAgeButton(
                                      iconPath: 'assets/images/Fashion/AgeIcon/icon-adult.png',
                                      isSelected: selectedAge == 'Adult',
                                      onTap: () => setState(() => selectedAge = 'Adult'),
                                   ),
                                 ],
                               ),
                             ),
                           ],
                        ),
                      ),
                      // Bottom Interactable Area (Tabs & Grid)
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _MainTabSelector(
                              tabs: FashionData.mainTabs,
                              selectedTab: selectedMainTab,
                              onTabSelected: _onMainTabChanged,
                            ),
                            Expanded(
                              child: _ContentArea(
                                selectedMainTab: selectedMainTab,
                                selectedSubTab: selectedSubTab,
                                inventory: _inventory,
                                selectedItem: _selectedItem,
                                onSubTabSelected: _onSubTabChanged,
                                onItemSelected: _onItemSelected,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                 // 3. Bottom Navigation Bar
                CustomBottomNavigationBar(
                  selectedIndex: 0, // Fashion Index (0 from bottom_navigation_bar.dart)
                  onItemTapped: (index) {
                     // Handle navigation
                     if (index == 0) Navigator.pushReplacementNamed(context, '/profile');
                     if (index == 1) {} // Stay here
                     if (index == 2) Navigator.pushReplacementNamed(context, '/lobby');
                     if (index == 3) Navigator.pushReplacementNamed(context, '/map');
                     if (index == 4) Navigator.pushReplacementNamed(context, '/club');
                  },
                  
                  // Callbacks matched to Lobby example:
                  onAvatarTapped: () => Navigator.pushReplacementNamed(context, '/profile'),
                  onFashionTapped: () {}, // User is on Fashion
                  onRoomTapped: () => Navigator.pushReplacementNamed(context, '/lobby'),
                  onMapTapped: () => Navigator.pushReplacementNamed(context, '/map'),
                  onClubTapped: () => Navigator.pushReplacementNamed(context, '/club'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAgeButton({
    required String iconPath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45, 
        height: 45,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5C9DFF) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8), // Adjust padding
        child: Image.asset(
           iconPath, 
           fit: BoxFit.contain,
           color: isSelected ? Colors.white : null, // Try to tint white if selected
        ),
      ),
    );
  }
}

// =============================================================================
// DATA & CONSTANTS
// =============================================================================
class FashionData {
  static const List<String> mainTabs = ['เสื้อผ้า', 'สีผิว', 'หน้าตา', 'ทรงผม'];
  static const List<String> subTabs = [
    'Grid',
    'Cloth', 
    'Shoes',
  ];

  static const List<Color> skinColors = [
    Color(0xFFFEEBDB),
    Color(0xFFFBCCAE),
    Color(0xFFFEBE86),
    Color(0xFFD08B50),
  ];
}

// =============================================================================
// SUB-WIDGETS
// =============================================================================

class _FashionBackground extends StatelessWidget {
  const _FashionBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset('assets/images/background/bg4.png', fit: BoxFit.cover),
    );
  }
}

class _MainTabSelector extends StatelessWidget {
  final List<String> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;

  const _MainTabSelector({
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      height: 45,
      child: Center(
        child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
        children: tabs.map((tab) {
          final isSelected = selectedTab == tab;
          return GestureDetector(
              onTap: () => onTabSelected(tab),
              child: Container(
                constraints: const BoxConstraints(minWidth: 95),
                // padding: const EdgeInsets.symmetric(horizontal: 25),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF002A50) : null,
                  gradient: isSelected
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF556CEB), Color(0xFF58A9EC)],
                        ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  tab,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          );
        }).toList(),
        ),
      ),
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  final String selectedMainTab;
  final String selectedSubTab;
  final List<InventoryItem> inventory;
  final InventoryItem? selectedItem;
  final ValueChanged<String> onSubTabSelected;
  final ValueChanged<InventoryItem> onItemSelected;

  const _ContentArea({
    required this.selectedMainTab,
    required this.selectedSubTab,
    required this.inventory,
    required this.selectedItem,
    required this.onSubTabSelected,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Determine category to filter
    List<InventoryItem> filteredItems = [];

    if (selectedMainTab == 'เสื้อผ้า') {
       if (selectedSubTab == 'Grid') {
         // Show both Cloth and Shoes
         filteredItems = inventory.where((i) => i.category == 'Cloth' || i.category == 'Shoes').toList();
       } else {
         filteredItems = inventory.where((i) => i.category == selectedSubTab).toList();
       }
    } else if (selectedMainTab == 'ทรงผม') {
       filteredItems = inventory.where((i) => i.category.toLowerCase() == 'hair').toList();
    } else if (selectedMainTab == 'หน้าตา') {
       filteredItems = inventory.where((i) => i.category.toLowerCase() == 'face').toList();
    } else if (selectedMainTab == 'สีผิว') {
       filteredItems = inventory.where((i) => i.category.toLowerCase() == 'skin').toList();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD0E8F2).withOpacity(0.9),
        border: const Border(top: BorderSide(color: Colors.black, width: 2)),
      ),
      child: Column(
        children: [
          // Sub-Tabs (Only for Clothes)
          if (selectedMainTab == 'เสื้อผ้า')
            _SubTabSelector(
              tabs: FashionData.subTabs,
              selectedTab: selectedSubTab,
              onTabSelected: onSubTabSelected,
            ),

          // Main Content Grid
          Expanded(
             child: filteredItems.isEmpty 
               ? const Center(child: Text("ไม่มีไอเทมในหมวดนี้"))
               : _FashionGrid(
                    items: filteredItems,
                    selectedItem: selectedItem,
                    onItemSelected: onItemSelected,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubTabSelector extends StatelessWidget {
  final List<String> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;

  const _SubTabSelector({
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: tabs.map((tab) => _buildIcon(tab)).toList(),
        ),
        ),
      ),
    );
  }

  Widget _buildIcon(String tab) {
    final isSelected = selectedTab == tab;
    // Basic icon map
    String iconAsset = 'assets/images/icon/all-fashion.png'; 
    if (tab == 'Cloth') iconAsset = 'assets/images/icon/dress-fashion.png';
    if (tab == 'Shoes') iconAsset = 'assets/images/icon/shoe-fashion.png';

    return GestureDetector(
      onTap: () => onTabSelected(tab),
      child: Container(
        width: 45,
        height: 45,
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF556AEB), Color(0xFF66E0FF)],
                )
              : null,
          color: isSelected ? null : Colors.white,
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFF5C9DFF), width: 2),
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Image.asset(iconAsset, fit: BoxFit.contain, errorBuilder: (_,__,___) => Icon(Icons.checkroom)),
        ),
      ),
    );
  }


}

class _FashionGrid extends StatelessWidget {
  final List<InventoryItem> items;
  final InventoryItem? selectedItem;
  final ValueChanged<InventoryItem> onItemSelected;

  const _FashionGrid({
    required this.items,
    required this.selectedItem,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, idx) => _ItemCard(
        item: items[idx],
        isSelected: selectedItem?.id == items[idx].id,
        onTap: () => onItemSelected(items[idx]),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final InventoryItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _ItemCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  String get _itemImagePath {
    // 1. Hair Logic
    if (item.category == 'Hair') {
      return 'assets/images/Fashion/HairStyle/hair0${item.riveId}.PNG';
    } 
    
    // 2. Cloth Logic
    if (item.category == 'Cloth') {
       return 'assets/images/Fashion/Cloth/Clothes${item.riveId + 1}.png';
    }

    return ''; 
  }

  // Helper to get category icon
  String? get _categoryIcon {
    if (item.category == 'Cloth') return 'assets/images/icon/dress-fashion.png';
    if (item.category == 'Shoes') return 'assets/images/icon/shoe-fashion.png';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8), 
          color: Colors.white, 
          border: isSelected 
            ? Border.all(color: const Color(0xFF5C9DFF), width: 3) 
            : Border.all(color: Colors.grey.shade300, width: 1), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                // Image Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: _itemImagePath.isNotEmpty
                      ? Transform.scale(
                          // Hair gets bigger (1.45), Cloth gets smaller (0.85)
                          scale: item.category == 'Hair' ? 1.45 : (item.category == 'Cloth' ? 0.85 : 1.0),
                          child: Image.asset(
                            _itemImagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey));
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                  ),
                ),

                // Name Only
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    item.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Category Icon (Top-Right)
            if (_categoryIcon != null)
              Positioned(
                top: 6, // Slightly more padding from top
                right: 6, // Slightly more padding from right
                child: Container(
                  width: 30, // Increased size (was 20)
                  height: 30,
                  padding: const EdgeInsets.all(4), // Slightly more padding inside
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF5C9DFF), width: 1.5), // Slightly thicker border
                  ),
                  child: Image.asset(_categoryIcon!, fit: BoxFit.contain),
                ),
              ),

            // Selected Checkmark
            if (isSelected)
              Positioned(
                top: 0, 
                right: 0,
                child: Container(
                  width: 18, // Adjust size
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF5C9DFF), 
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}