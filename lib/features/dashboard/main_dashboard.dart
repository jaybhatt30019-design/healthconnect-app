// lib/features/dashboard/main_dashboard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthconnect/features/caregiver/caregiver_home.dart';
import 'package:healthconnect/features/parent/parent_home.dart';
import 'package:healthconnect/features/shared/medicines_screen.dart';
import 'package:healthconnect/features/shared/appointments_screen.dart';
import 'package:healthconnect/features/shared/emergency_screen.dart';
import 'package:healthconnect/features/shared/more_screen.dart';
import 'package:healthconnect/features/dashboard/setup_checklist_dialog.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/callkit_handler.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/features/emergency/incoming_call_screen.dart';

class MainDashboard extends StatefulWidget {
  final bool isCaregiver;
  final int initialIndex;

  const MainDashboard({
    super.key,
    required this.isCaregiver,
    this.initialIndex = 0,
  });

  @override
  State<MainDashboard> createState() =>
      _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  late int _currentIndex;
  late List<Widget> _screens;

  StreamSubscription<EmergencyCall?>? _callSub;
  String? _lastHandledCallId;

  // ✅ Key to access banner's refresh method
  final _bannerKey =
      GlobalKey<SetupChecklistBannerState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _screens = [
      widget.isCaregiver
          ? CaregiverHome(
              onAppointmentTap: () {
                setState(() => _currentIndex = 2);
              },
            )
          : ParentHome(
              onAppointmentTap: () {
                setState(() => _currentIndex = 2);
              },
            ),
      MedicinesScreen(),
      AppointmentsScreen(),
      EmergencyScreen(isCaregiver: widget.isCaregiver),
      MoreScreen(),
    ];

    _startIncomingCallListener();
  }

  void _startIncomingCallListener() {
    _callSub = EmergencyService()
        .incomingCallStream()
        .listen((call) {
      if (call == null) return;
      if (!mounted) return;

      if (CallKitHandler.isHandlingCall) {
        debugPrint(
            '[MainDashboard] CallKit handling — skipping');
        return;
      }

      if (_lastHandledCallId == call.id) return;
      _lastHandledCallId = call.id;

      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              IncomingCallScreen(
                call: call,
                isParentReceiving: !widget.isCaregiver,
              ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Wrap body with banner
      // Banner sits at bottom, content above it
      body: SetupChecklistBanner(
        key: _bannerKey,
        isCaregiver: widget.isCaregiver,
        switchTab: (index) {
          if (mounted) {
            setState(() => _currentIndex = index);
          }
        },
        child: _screens[_currentIndex],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0E7C6B),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // ✅ Refresh checklist on every tab switch
          // Picks up any changes made on the previous tab
          _bannerKey.currentState?.refresh();
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.medication),
              label: 'Medications'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Appointments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber_rounded),
              label: 'Emergency'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view),
              label: 'More'),
        ],
      ),
    );
  }
}