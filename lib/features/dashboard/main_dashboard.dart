import 'package:flutter/material.dart';

import 'package:healthconnect/features/caregiver/caregiver_home.dart';
import 'package:healthconnect/features/parent/parent_home.dart';
import 'package:healthconnect/features/shared/medicines_screen.dart';
import 'package:healthconnect/features/shared/appointments_screen.dart';
import 'package:healthconnect/features/shared/emergency_screen.dart';
import 'package:healthconnect/features/shared/more_screen.dart';
import 'package:healthconnect/features/dashboard/setup_checklist_dialog.dart';

class MainDashboard extends StatefulWidget {
  final bool isCaregiver;
  final int initialIndex;

  const MainDashboard({
    super.key, 
    required this.isCaregiver,
    this.initialIndex = 0,});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  late int _currentIndex;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _screens = [
      widget.isCaregiver ? CaregiverHome(
            onAppointmentTap: () {
              setState(() => _currentIndex = 2); // appointments tab index
            },) : ParentHome(
          onAppointmentTap: () {
            setState(() => _currentIndex = 2);
          },),
      MedicinesScreen(),
      AppointmentsScreen(),
      EmergencyScreen(isCaregiver: widget.isCaregiver),
      MoreScreen(),
    ];
      // ✅ ADD THIS BLOCK — checklist dialog
  // 800ms delay so dashboard renders first
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        SetupChecklistDialog.showIfNeeded(
          context: context,
          isCaregiver: widget.isCaregiver,
          switchTab: (index) {
            if (mounted) {
              setState(() => _currentIndex = index);
            }
          },
        );
      }
    });
  });
  //
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
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: "Emergency"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "More"),
        ],
      ),
    );
  }
}