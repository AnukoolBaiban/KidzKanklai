import 'package:flutter/material.dart';
import 'package:flutter_application_1/api_service.dart';

import 'package:flutter_application_1/widgets/bottom_navigation_bar.dart';
import 'package:flutter_application_1/widgets/custom_top_bar.dart';

class MapScreen extends StatefulWidget {
  final User? user;

  const MapScreen({super.key, this.user});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 2; // Map = index 2

  final List<String> _menuItems = [
    'สนามสอบ1',
    'สนามสอบ2',
    'สนามสอบ3',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            CustomTopBar(
              user: widget.user,
              onNotificationTapped: () {
                Navigator.pushNamed(context, '/notification');
              },
              onSettingsTapped: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),

            // Main Content
            Expanded(
              child: Stack(
                children: [
                  Center(child: Text('Map Page')),
                  
                ],
              ),
            ),

            // Bottom Navigation
            CustomBottomNavigationBar(
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
          ],
        ),
      ),
    );
  }
}
