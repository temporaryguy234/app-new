import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../home/swipe_screen.dart';
import '../saved/saved_jobs_screen.dart';
import '../applications/applications_screen.dart';
import '../filter/filter_screen.dart';
import '../profile/profile_screen.dart';
import '../specials/specials_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  const MainScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  final List<Widget> _screens = [
    const SwipeScreen(),
    const SavedJobsScreen(),
    const ApplicationsScreen(),
    const FilterScreen(),
    const ProfileScreen(),
    const SpecialsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            activeIcon: Icon(Icons.bookmark),
            label: 'Gespeichert',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Bewerbungen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_outlined),
            activeIcon: Icon(Icons.tune),
            label: 'Filter',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            activeIcon: Icon(Icons.star),
            label: 'Specials',
          ),
        ],
      ),
    );
  }
}
