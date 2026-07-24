// lib/widgets/universal_bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class UniversalBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final double? iconSize;
  final bool showLabels;
  final EdgeInsetsGeometry? padding;

  const UniversalBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
    this.iconSize = 28,
    this.showLabels = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  factory UniversalBottomNavBar.passenger({
    required int currentIndex,
    required Function(int) onTap,
  }) {
    return UniversalBottomNavBar(
     currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.book_online),
          label: 'Bookings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.message),
          label: 'Messages',
        ),
      ],
      selectedColor: hexStringToColor("365770"),
      unselectedColor: Colors.grey,
    );
  }

  // Factory constructor untuk Driver
  factory UniversalBottomNavBar.driver({
    required int currentIndex,
    required Function(int) onTap,
  }) {
    return UniversalBottomNavBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.drive_eta), 
          label: 'My Rides'
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.message), 
          label: 'Messages'
        ),
      ],
      selectedColor: hexStringToColor("365770"),
      unselectedColor: Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white;
    final selectedClr = selectedColor ?? hexStringToColor("365770");
    final unselectedClr = unselectedColor ?? Colors.grey;

    return Padding(
      padding: padding!,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            backgroundColor: bg,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedItemColor: selectedClr,
            unselectedItemColor: unselectedClr,
            selectedFontSize: 13,
            unselectedFontSize: 13,
            showSelectedLabels: showLabels,
            showUnselectedLabels: showLabels,
            iconSize: iconSize!,
            currentIndex: currentIndex,
            onTap: onTap,
            items: items,
          ),
        ),
      ),
    );
  }
}