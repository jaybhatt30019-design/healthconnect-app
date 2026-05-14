import 'package:flutter/material.dart';

import 'package:healthconnect/features/caregiver/caregiver_home.dart';
import 'package:healthconnect/features/parent/parent_home.dart';
import 'package:healthconnect/features/shared/medicines_screen.dart';
import 'package:healthconnect/features/shared/appointments_screen.dart';
import 'package:healthconnect/features/shared/emergency_screen.dart';
import 'package:healthconnect/features/shared/more_screen.dart';

class MainDashboard extends StatefulWidget {
  final bool isCaregiver;

  const MainDashboard({super.key, required this.isCaregiver});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      widget.isCaregiver ? CaregiverHome() : ParentHome(),
      MedicinesScreen(),
      AppointmentsScreen(),
      EmergencyScreen(),
      MoreScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0E7C6B),
        unselectedItemColor: Colors.grey,

        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.medication), label: "Medications"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Appointments"),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: "Emergency"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "More"),
        ],
      ),
    );
  }
}