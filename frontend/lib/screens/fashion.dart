import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image;

import 'package:flutter_application_1/api_service.dart';
import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/config/rive_cache.dart';

// =============================================================================
// PAGE WIDGET
// =============================================================================
class FashionPage extends StatefulWidget {
  const FashionPage({super.key});

  @override
  State<FashionPage> createState() => _FashionPageState();
}

class _FashionPageState extends State<FashionPage> {
  // --- STATE ---
  String selectedMainTab = FashionData.mainTabs[0]; // เสื้อผ้า
  String selectedSubTab = FashionData.subTabs[0];   // Grid
  String selectedAge = 'Kid';
  int selectedSkinColorIndex = 0;

  // --- LOGIC DATA ---
  List<InventoryItem> _inventory = [];
  // key = category (e.g. 'Hair', 'Outfit'), value = item id string
  Map<String, String> _equippedByCategory = {};
  bool _isLoading = true;
  User? _user;

  // --- RIVE CONTROLLERS ---
  SMINumber? _poseInput;
  SMINumber? _hairInput;
  SMINumber? _faceInput;
  SMINumber? _skinInput;
  SMINumber? _clothInput;
  SMINumber? _armInput; // [ADDED]
  SMITrigger? _tapInput;
  bool _isRiveLoaded = false;
  StateMachineController? _controller;

  // --- POPUP STATE (From fashion-best.dart) ---
  String? _showingAgeText;
  double? _agePopupTop;
  Timer? _hideTimer;

  // --- INIT ---
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final inv = await ApiService.getInventory();
      final eq = await ApiService.getEquipped();
      final user = await ApiService.getProfile(0);

      if (mounted) {
        setState(() {
          _inventory = inv;
          // สร้าง map: category -> item id
          _equippedByCategory = { for (var e in eq) e.category: e.id };
          _user = user;
          _isLoading = false;
          
          if (_user != null) {
            String bt = _user!.bodyType.toUpperCase();
            if (bt == 'ADULT') selectedAge = 'Adult';
            else if (bt == 'TEEN') selectedAge = 'Teen';
            else selectedAge = 'Kid';
          }
          
          _syncRiveToEquipped();
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- RIVE LOGIC ---
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
      // 1. Try using User Profile Data
      if (_user != null) {
        if (_hairInput != null) _hairInput!.value = parseId(_user!.equippedHair);
        if (_faceInput != null) _faceInput!.value = parseId(_user!.equippedFace);
        if (_skinInput != null) _skinInput!.value = parseId(_user!.equippedSkin);
        if (_clothInput != null) _clothInput!.value = parseId(_user!.equippedOutfit);
        if (_armInput != null) _armInput!.value = parseId(_user!.equippedOutfit);
        return;
      }

      // 2. Fallback: ใช้ _equippedByCategory + _inventory หา riveId
      double getRiveId(String category) {
        final itemId = _equippedByCategory[category];
        if (itemId == null || itemId.isEmpty) return 0;
        final item = _inventory.firstWhere(
          (i) => i.id == itemId,
          orElse: () => InventoryItem(type: '', id: '', category: ''),
        );
        return item.riveId.toDouble();
      }

      if (_hairInput != null) _hairInput!.value = getRiveId('Hair');
      if (_faceInput != null) _faceInput!.value = getRiveId('Face');
      if (_skinInput != null) _skinInput!.value = getRiveId('Skin');
      if (_clothInput != null) _clothInput!.value = getRiveId('Outfit');
      if (_armInput != null) _armInput!.value = getRiveId('Outfit');

    } catch (e) {
      print("Error syncing Rive: $e");
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

      for (var input in controller.inputs) {
        if (input.name == 'Pose') _poseInput = input as SMINumber;
        if (input.name == 'HairID') _hairInput = input as SMINumber;
        if (input.name == 'FaceID') _faceInput = input as SMINumber;
        if (input.name == 'SkinID') _skinInput = input as SMINumber;
        if (input.name == 'OutfitID') _clothInput = input as SMINumber;
        if (input.name == 'Tapcharacter' && input is SMITrigger) _tapInput = input;
      }
      
      _syncRiveToEquipped();
    }
    if (mounted) setState(() => _isRiveLoaded = true);
  }

  String _getModelAsset() {
    if (_user != null) {
      final bt = _user!.bodyType.toUpperCase();
      if (bt == 'ADULT') return 'assets/animation/adult.riv';
      if (bt == 'TEEN') return 'assets/animation/teen.riv';
      return 'assets/animation/kid.riv';
    }
    int lvl = _user?.level ?? 1;
    if (lvl >= 30) return 'assets/animation/adult.riv';
    if (lvl >= 15) return 'assets/animation/teen.riv';
    return 'assets/animation/kid.riv';
  }

  // --- ACTIONS ---
  void _onMainTabChanged(String tab) {
    setState(() => selectedMainTab = tab);
    if (tab == 'เสื้อผ้า') {
        setState(() => selectedSubTab = 'Grid');
    }
  }

  void _onSubTabChanged(String tab) {
    setState(() => selectedSubTab = tab);
  }

  void _onAgeSelected(String ageType) async {
    setState(() => selectedAge = ageType);
    _showAgePopup(ageType);

    String dbForm = 'KID';
    if (ageType == 'Teen') dbForm = 'TEEN';
    if (ageType == 'Adult') dbForm = 'ADULT';

    bool success = await ApiService.changeBodyType(dbForm);
    if (success && mounted) {
      _fetchData(); // Refresh the character model
    }
  }

  void _showAgePopup(String ageType) {
    String text = '';
    double top = 0;
    switch (ageType) {
      case 'Kid':
        text = 'เด็ก';
        top = 10 + 9; // AgeSelector top (10) + center offset
        break;
      case 'Teen':
        text = 'วัยรุ่น';
        top = 10 + 58 + 9; // AgeSelector top + (button 50 + gap 8) + center offset
        break;
      case 'Adult':
        text = 'ผู้ใหญ่';
        top = 10 + 116 + 9; // AgeSelector top + (button+gap)*2 + center offset
        break;
    }

    _hideTimer?.cancel();
    setState(() {
      _showingAgeText = text;
      _agePopupTop = top;
    });

    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showingAgeText = null;
          _agePopupTop = null;
        });
      }
    });
  }

  void _onSkinColorSelected(int index) {
      setState(() => selectedSkinColorIndex = index);
      // Logic for skin color selection if it were a simple index
      // But we use InventoryItems for skin usually.
      // If 'Skin' tab is selected, we should rely on _onItemSelected with InventoryItem.
  }

  Future<void> _onItemSelected(InventoryItem item) async {
    // อัปเดต map ทันที (optimistic) ไม่ต้องรอ API
    setState(() {
      _equippedByCategory[item.category] = item.id;
    });
    
    // Rive Preview
    if (item.category == 'Hair' && _hairInput != null) _hairInput!.value = item.riveId.toDouble();
    if (item.category == 'Face' && _faceInput != null) _faceInput!.value = item.riveId.toDouble();
    if (item.category == 'Skin' && _skinInput != null) _skinInput!.value = item.riveId.toDouble();
    if (item.category == 'Outfit' && _clothInput != null) _clothInput!.value = item.riveId.toDouble();
    if (item.category == 'Outfit' && _armInput != null) _armInput!.value = item.riveId.toDouble();

    // API Call
    final success = await ApiService.equipItem(item.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("สวมใส่ ${item.name} เรียบร้อย"),
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Refresh เพื่อ sync ข้อมูลจาก DB (ไม่ต้อง reset equippedByCategory เพราะ _fetchData จะทำให้)
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          const _FashionBackground(),
          
          Column(
            children: [
              // 1. Top Bar with dark background overlay
              Container(
                padding: EdgeInsets.only(top: topPadding),
                color: Colors.black.withOpacity(0.4),
                child: CustomTopBar(
                  onNotificationTapped: () => Navigator.pushNamed(context, '/notification'),
                  onSettingsTapped: () => Navigator.pushNamed(context, '/setting'),
                ),
              ),

              // 2. Main Body
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Character Area
                        Expanded(
                          flex: 4,
                          child: GestureDetector(
                              onTap: () {
                                if (_tapInput != null) _tapInput!.fire();
                              },
                              child: Container(
                                color: Colors.transparent, // Hit test
                                alignment: Alignment.center,
                                child: (_isLoading || _user == null)
                                  ? const CircularProgressIndicator()
                                  : Transform.translate(
                                      offset: Offset(0, _user!.bodyType.toUpperCase() == 'KID' ? 50 : 0), // เลื่อนลง 50 สำหรับร่างเด็ก (รอโหลดโมเดลเสร็จก่อน)
                                      child: (RiveCache().getFile(_getModelAsset()) != null
                                          ? RiveAnimation.direct(
                                              RiveCache().getFile(_getModelAsset())!,
                                              fit: BoxFit.contain,
                                              onInit: _onRiveInit,
                                              stateMachines: const ['State Machine 1'],
                                            )
                                          : RiveAnimation.asset(
                                              _getModelAsset(),
                                              fit: BoxFit.contain,
                                              onInit: _onRiveInit,
                                            )
                                      ),
                                    ),
                              ),
                          ),
                        ),

                        // Bottom Interactable Area
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
                                  selectedItemIndex: 0,
                                  selectedSkinColorIndex: selectedSkinColorIndex,
                                  onSubTabSelected: _onSubTabChanged,
                                  onItemSelected: (index) {},
                                  onSkinColorSelected: _onSkinColorSelected,
                                  // New Data Props
                                  inventory: _inventory,
                                  equippedByCategory: _equippedByCategory,
                                  onInventoryItemSelected: _onItemSelected,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Age Selector (Right Side)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _AgeSelector(
                        selectedAge: selectedAge,
                        userLevel: _user?.level ?? 1,
                        onAgeSelected: _onAgeSelected,
                      ),
                    ),

                    // Age Popup
                    if (_showingAgeText != null)
                      _AgePopup(text: _showingAgeText!, top: _agePopupTop ?? 0),
                  ],
                ),
              ),

              // 3. Bottom Nav
              SafeArea(
                top: false,
                child: CustomBottomNavigationBar(
                  selectedIndex: 0,
                  user: _user,
                  onItemTapped: (index) {},
                  onAvatarTapped: () => Navigator.pushReplacementNamed(context, '/profile'),
                  onFashionTapped: () {},
                  onRoomTapped: () => Navigator.pushReplacementNamed(context, '/lobby'),
                  onMapTapped: () => Navigator.pushReplacementNamed(context, '/map'),
                  onClubTapped: () => Navigator.pushReplacementNamed(context, '/club'),
                ),
              ),
            ],
          ),
        ],
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
      // Ensure this asset exists, otherwise fallback or handle error
      child: Image.asset(
        'assets/images/bgFashion.png', 
        fit: BoxFit.cover,
        errorBuilder: (_,__,___) => Image.asset('assets/images/background/bg4.png', fit: BoxFit.cover),
      ),
    );
  }
}

class _AgeSelector extends StatelessWidget {
  final String selectedAge;
  final int userLevel;
  final ValueChanged<String> onAgeSelected;

  const _AgeSelector({
    required this.selectedAge, 
    required this.userLevel,
    required this.onAgeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildButton('Kid', 'assets/images/Fashion/AgeIcon/icon-kid.png'),
        const SizedBox(height: 8),
        _buildButton('Teen', 'assets/images/Fashion/AgeIcon/icon-teen.png'),
        const SizedBox(height: 8),
        _buildButton('Adult', 'assets/images/Fashion/AgeIcon/icon-adult.png'),
      ],
    );
  }

  Widget _buildButton(String ageType, String assetPath) {
    final isSelected = selectedAge == ageType;
    
    // Check if form is unlocked
    bool isUnlocked = true;
    int requiredLevel = 0;
    if (ageType == 'Teen' && userLevel < 15) { isUnlocked = false; requiredLevel = 15; }
    if (ageType == 'Adult' && userLevel < 30) { isUnlocked = false; requiredLevel = 30; }

    final circle = Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUnlocked
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF556CEB), Color(0xFF58A9EC)],
              )
            : null,
        color: isUnlocked ? null : const Color(0xFF9E9E9E),
        border: Border.all(
          color: Colors.white,
          width: isSelected ? 3.0 : 0.0,
        ),
        boxShadow: [
          if (isSelected && isUnlocked)
            BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: isUnlocked
          ? SizedBox(
              width: 35,
              height: 35,
              child: Image.asset(assetPath, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Colors.white, size: 16),
                const SizedBox(height: 2),
                Text(
                  'Lv.$requiredLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ),
    );

    return GestureDetector(
      onTap: (isUnlocked && !isSelected) ? () => onAgeSelected(ageType) : null,
      child: circle,
    );
  }
}

class _AgePopup extends StatelessWidget {
  final String text;
  final double top;

  const _AgePopup({required this.text, required this.top});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: 70, // To the left of the buttons
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: tabs.map((tab) {
          final isSelected = selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(tab),
              child: Container(
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
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  final String selectedMainTab;
  final String selectedSubTab;
  final int selectedItemIndex;
  final int selectedSkinColorIndex;
  final ValueChanged<String> onSubTabSelected;
  final ValueChanged<int> onItemSelected;
  final ValueChanged<int> onSkinColorSelected;

  final List<InventoryItem> inventory;
  final Map<String, String> equippedByCategory; // category -> item id
  final ValueChanged<InventoryItem> onInventoryItemSelected;

  const _ContentArea({
    required this.selectedMainTab,
    required this.selectedSubTab,
    required this.selectedItemIndex,
    required this.selectedSkinColorIndex,
    required this.onSubTabSelected,
    required this.onItemSelected,
    required this.onSkinColorSelected,
    required this.inventory,
    required this.equippedByCategory,
    required this.onInventoryItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Filter Items
    List<InventoryItem> filteredItems = [];
    if (selectedMainTab == 'เสื้อผ้า') {
       if (selectedSubTab == 'Grid') {
         filteredItems = inventory.where((i) => i.category == 'Outfit' || i.category == 'Shoes' || i.category == 'Cloth').toList();
       } else if (selectedSubTab == 'Cloth') {
         filteredItems = inventory.where((i) => i.category == 'Outfit' || i.category == 'Cloth').toList();
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
          // Sub-Tabs
          if (selectedMainTab == 'เสื้อผ้า')
            _SubTabSelector(
              tabs: FashionData.subTabs,
              selectedTab: selectedSubTab,
              onTabSelected: onSubTabSelected,
            ),
            
          if (selectedMainTab == 'หน้าตา' || selectedMainTab == 'ทรงผม')
            const SizedBox(height: 20),

          // Main Content
          Expanded(
            child: selectedMainTab == 'สีผิว'
                ? _SkinColorSelector(
                    colors: FashionData.skinColors,
                    selectedIndex: selectedSkinColorIndex,
                    onColorSelected: onSkinColorSelected,
                    inventory: filteredItems,
                    equippedByCategory: equippedByCategory,
                    onInventoryItemSelected: onInventoryItemSelected,
                  )
                : _FashionGrid(
                    items: filteredItems,
                    equippedByCategory: equippedByCategory,
                    onItemSelected: onInventoryItemSelected,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: tabs.map((tab) => _buildIcon(tab)).toList(),
      ),
    );
  }

  Widget _buildIcon(String tab) {
    final isSelected = selectedTab == tab;
    // Map assets
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
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0xFF4AC4F3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Image.asset(iconAsset, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.checkroom)),
        ),
      ),
    );
  }
}

class _FashionGrid extends StatelessWidget {
  final List<InventoryItem> items;
  final Map<String, String> equippedByCategory;
  final ValueChanged<InventoryItem> onItemSelected;

  const _FashionGrid({
    required this.items,
    required this.equippedByCategory,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text("ไม่มีไอเทมในหมวดนี้"));
    }

    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        // ติ๊กถูกถ้า item นี้ถูกเลือกใน category นั้น
        final isSelected = equippedByCategory[item.category] == item.id;
        return _ItemCard(
          item: item,
          isSelected: isSelected,
          onTap: isSelected ? null : () => onItemSelected(item),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  final InventoryItem item;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ItemCard({
    required this.item,
    required this.isSelected,
    this.onTap,
  });

  String get _itemImagePath {
    final cat = item.category.toLowerCase();
    if (cat == 'hair') {
      return 'assets/images/Fashion/HairStyle/${item.name}.PNG';
    } else if (cat == 'outfit' || cat == 'cloth') {
      return 'assets/images/Fashion/Outfit/${item.name}.PNG';
    } else if (cat == 'face') {
      return 'assets/images/Fashion/FaceStyle/${item.name}.PNG';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFCEFFB2), Color(0xFF6FBBDE)],
                )
              : null,
          color: isSelected ? null : const Color(0xFFAAD7EA),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey.shade300 : Colors.white,
            borderRadius: BorderRadius.circular(1),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  // Icon Top Right (Type) - Only show for Cloth and Shoes
                  if (item.category == 'Cloth' || item.category == 'Shoes')
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Container(
                          width: 35,
                          height: 35,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFC8E5F1),
                              width: 1.5,
                            ),
                          ),
                          // Determine small icon based on category
                          child: Image.asset(
                            item.category == 'Shoes' ? 'assets/images/icon/shoe-fashion.png' :
                            'assets/images/icon/dress-fashion.png',
                            errorBuilder: (_,__,___) => const Icon(Icons.star, size: 10),
                          ),
                        ),
                      ),
                    ),

                  // Main Image
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Center(
                        child: _itemImagePath.isNotEmpty 
                          ? Transform.scale(
                              scale: item.category.toLowerCase() == 'face' ? 2.5 : 1.8,
                              child: Image.asset(
                                _itemImagePath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                              ),
                            )
                          : const Icon(Icons.checkroom, color: Colors.grey),
                      ),
                    ),
                  ),

                  // Text Name
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 8.0,
                      top: 4.0,
                      left: 4,
                      right: 4,
                    ),
                    child: Text(
                      item.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFCEFFB2), Color(0xFF70BCDE)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinColorSelector extends StatelessWidget {
  final List<Color> colors;
  final int selectedIndex;
  final ValueChanged<int> onColorSelected;
  final List<InventoryItem> inventory;
  final Map<String, String> equippedByCategory;
  final ValueChanged<InventoryItem> onInventoryItemSelected;

  const _SkinColorSelector({
    required this.colors,
    required this.selectedIndex,
    required this.onColorSelected,
    required this.inventory,
    required this.equippedByCategory,
    required this.onInventoryItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    // If we have actual skin items from API, display them as colors if possible, or just buttons
    // For now, mapping colors to API items is tricky without explicit color codes in API.
    // We will assume the inventory order matches color order or just display available skins.
    
    // If inventory is empty, show default UI for visual fallback
    if (inventory.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 40),
          alignment: Alignment.topCenter,
          child: const Text("ไม่มีไอเทมสีผิว"),
        );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40),
      alignment: Alignment.topCenter,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        children: List.generate(inventory.length, (index) {
          final item = inventory[index];
          final isSelected = equippedByCategory[item.category] == item.id;
          
          // Fallback colors if we don't have enough defined
          Color displayColor = Colors.grey;
          if (index < colors.length) displayColor = colors[index];
          
          return GestureDetector(
            onTap: isSelected ? null : () {
               onColorSelected(index);
               onInventoryItemSelected(item);
            },
            child: Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFCEFFB2), Color(0xFF70BCDE)],
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                border: isSelected
                    ? null
                    : Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: displayColor,
                  shape: BoxShape.circle,
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 30),
                      )
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}