import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';

import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/right_side_menu.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';
import 'package:flutter_application_1/widgets/character_widget.dart';

class LobbyScreen extends StatefulWidget {
  final User? user;

  const LobbyScreen({Key? key, this.user}) : super(key: key);

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int _selectedIndex = 1; // Default to Lobby (Room)
  User? _user; // Local user state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user; // Initialize with passed user
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Always fetch latest data to ensure updates from Fashion/Tasks are reflected
    // even if widget.user is passed (it might be stale)
    final profile = await ApiService.getProfile(0);
    if (mounted) {
      setState(() {
        if (profile != null) {
          _user = profile;
        }
        _isLoading = false;
      });
    }
  }

  // Right Menu Items
  List<MenuItem> get _menuItems => [
    MenuItem(
      imagePath: "assets/images/icon/iconAchievement.png",
      label: 'ความสำเร็จ',
      onTap: () {
        Navigator.pushNamed(context, '/achievement');
      },
    ),
    MenuItem(
      imagePath: "assets/images/icon/iconQuest.png",
      label: 'ภารกิจ',
      onTap: () {
        Navigator.pushNamed(context, '/createnormalquest');
      },
    ),
    MenuItem(
      imagePath: "assets/images/item/Gasha.png",
      label: 'กล่องสุ่ม',
      onTap: () {
        Navigator.pushNamed(context, '/gasha');
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background/bg3.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar - ใช้ CustomTopBar
              CustomTopBar(
                user: _user, // Use local state
                onNotificationTapped: () {
                  Navigator.pushNamed(context, '/notification');
                },
                onSettingsTapped: () {
                  Navigator.pushNamed(context, '/setting');
                },
              ),

              // Main Content
              Expanded(
                // Added Expanded to fill remaining space
                child: Stack(
                  alignment: Alignment.center, // Center the character
                  children: [
                    // Character Widget - อยู่ชั้นล่างสุด
                    Positioned(
                      bottom: -50, // Adjust position as needed
                      child: _isLoading || _user == null
                          ? const SizedBox() // Or CircularProgressIndicator() if you want to see it loading
                          : CharacterWidget(
                              height: 600, 
                              width: 500,
                              user: _user, // Pass Updated User to Character
                            ),
                    ),

                    // Right Side Menu Component
                    RightSideMenu(menuItems: _menuItems),
                  ],
                ),
              ),

              // Bottom Navigation
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: CustomBottomNavigationBar(
                  selectedIndex: _selectedIndex,
                  onItemTapped: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });

                    switch (index) {
                      case 0:
                        Navigator.pushNamed(context, '/fashion');
                        break;
                      case 1:
                        Navigator.pushNamed(context, '/lobby');
                        break;
                      case 2:
                        Navigator.pushNamed(context, '/map');
                        break;
                      case 3:
                        Navigator.pushNamed(context, '/club');
                        break;
                    }
                  },
                  onAvatarTapped: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}