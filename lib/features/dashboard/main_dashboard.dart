// lib/features/dashboard/main_dashboard.dart

import 'dart:async';
import 'package:Vitanex/features/payment/payment_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Vitanex/core/services/permission_helper.dart';
import 'package:Vitanex/features/caregiver/caregiver_home.dart';
import 'package:Vitanex/features/parent/parent_home.dart';
import 'package:Vitanex/features/shared/medicines_screen.dart';
import 'package:Vitanex/features/shared/appointments_screen.dart';
import 'package:Vitanex/features/shared/emergency_screen.dart';
import 'package:Vitanex/features/shared/more_screen.dart';
import 'package:Vitanex/features/dashboard/setup_checklist_dialog.dart';
import 'package:Vitanex/core/services/emergency_service.dart';
// import 'package:Vitanex/core/services/callkit_handler.dart';
import 'package:Vitanex/models/emergency_call_model.dart';
import 'package:Vitanex/features/emergency/incoming_call_screen.dart';
import 'package:in_app_update/in_app_update.dart';

class MainDashboard extends StatefulWidget {
  final bool isCaregiver;
  final int initialIndex;
  final bool willCareGiverPayAndHasCareGiver;
final String caregiverId;
final String code;
  const MainDashboard({
    super.key,
    required this.isCaregiver,
    this.initialIndex = 0,
    this.willCareGiverPayAndHasCareGiver = false,
    this.caregiverId = "",
    this.code = "HC-1-1-1-1"
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

      bool isLoading  = false;

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

  // if the user is not a caregiver then and only then do payment and check for the payment 
if(!widget.isCaregiver){
  _checkSubscriptionAndRoute();
}
   askPermission();
    _startIncomingCallListener();


    //checkUpdate();
  }


Future<void> checkUpdate() async{

  await InAppUpdate.checkForUpdate().then((info){

    setState(() {
      
      if(info.updateAvailability == UpdateAvailability.updateAvailable){
        _updateApp();
      }
    });
  });
}

Future<void> _updateApp() async{

  await InAppUpdate.startFlexibleUpdate();

  InAppUpdate.completeFlexibleUpdate().then((vl){}).catchError(
    (error) {


    }
  );
}

  
  Future<void> _checkSubscriptionAndRoute() async {
isLoading = true;
setState(() {
  
});
    
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) return;
  try {
    // 1. Fetch current user data profile
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUid)
        .get();
    if (!userDoc.exists) return;
    final userData = userDoc.data()!;

    bool isPremium = false;

    // Treats a doc as premium only if hasTakenSubscription is true AND
    // subscriptionExpiresAt is still in the future. Docs with no expiry
    // stored (e.g. pre-annual "lifetime" purchases) are treated as
    // expired, so every user ends up on the new 1-year cycle.
    bool isSubscriptionActive(Map<String, dynamic> data) {
      final hasTaken = data['hasTakenSubscription'] == true;
      if (!hasTaken) return false;

      final expiresAt = data['subscriptionExpiresAt'];
      if (expiresAt is Timestamp) {
        return expiresAt.toDate().isAfter(DateTime.now());
      }

      return false;
    }

    // 2. Route Check Strategy
    if (userData['role'] == 'parent') {
      // If Parent: Look at their own subscription flag + expiry directly
      isPremium = isSubscriptionActive(userData);
    } else {
      // If Child/Caregiver: Check if they themselves paid OR read their parent's profile state
      if (isSubscriptionActive(userData)) {
        isPremium = true;
      } else {
        final String linkedParentId = userData['parentId'] ?? '';
        if (linkedParentId.isNotEmpty) {
          final parentDoc = await FirebaseFirestore.instance
              .collection("users")
              .doc(linkedParentId)
              .get();

          if (parentDoc.exists) {
            isPremium = isSubscriptionActive(parentDoc.data()!);
          }
        }
      }
    }

    // 3. Navigation Routing
    if (!mounted) return;

    if (isPremium) {

      isLoading = false;
setState(() {
  
});
    
      // Premium active: Move directly into app workspace core dashboard
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
      // );
    } else {
      isLoading = false;

    
      // No active premium found: Force redirect straight onto the storefront checkout layout
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PaymentPage(isCaregiver: widget.isCaregiver,caregiverId :widget.caregiverId,code: widget.code)),
      );
    }
  } catch (e) {
    debugPrint("Subscription verification pipeline error: $e");
  }
}

Future<void> askPermission() async{
   if (mounted) {
      await PermissionHelper.requestAll(context);
    }
}
  void _startIncomingCallListener() {
    _callSub = EmergencyService()
        .incomingCallStream()
        .listen((call) {
      if (call == null) return;
      if (!mounted) return;

      // if (CallKitHandler.isHandlingCall) {
      //   debugPrint(
      //       '[MainDashboard] CallKit handling — skipping');
      //   return;
      // }

      if (_lastHandledCallId == call.id) return;
      _lastHandledCallId = call.id;


// check here one time  for incoming call handle 

// commented this 
      // Navigator.of(context, rootNavigator: true).push(
      //   MaterialPageRoute(
      //     fullscreenDialog: true,
      //     builder: (_) =>
      //         IncomingCallScreen(
      //           call: call,
      //           isParentReceiving: !widget.isCaregiver,
      //         ),
      //   ),
      // );
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading? Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          
        ),
      ),
    ): Scaffold(
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