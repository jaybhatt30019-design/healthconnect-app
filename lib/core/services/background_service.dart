
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Future<void> initializeBackgroundService() async {
//   final service = FlutterBackgroundService();

//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'my_foreground', 
//     'Incoming Call Service',
    
//     description: 'This channel is used for monitoring fastcall status.',
//     importance: Importance.low, 
//   );

//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();


//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       autoStart: true,
//       isForegroundMode: true,
      
//       notificationChannelId: 'my_foreground', 
//       initialNotificationTitle: 'FastCall Active',
//       initialNotificationContent: 'Monitoring incoming calls...',
//       foregroundServiceNotificationId: 888,
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: true,
//       onForeground: onStart,
//     ),
//   );

//   service.startService();
// }


// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
// WidgetsFlutterBinding.ensureInitialized();
  
//   // await Firebase.initializeApp(
//   //   options: const FirebaseOptions(
//   //    //////// options here ..................................
//   //   )
//   // );


// // service.on("setAsForeground").listen((event) {
//     if (service is AndroidServiceInstance) {
//       service.setAsForegroundService();
//     }

//  service.on("goToJoinCall").listen((event) async {


// ///// you may uncomment this ....................

//     // final intent = AndroidIntent(
//     //       action: 'android.intent.action.MAIN',
//     //       category: 'android.intent.category.LAUNCHER',
//     //       package: 'com.example.fastcall', // Double check this matches your app's package name
//     //       componentName: 'com.example.fastcall.MainActivity',
//     //       flags: [
//     //         Flag.FLAG_ACTIVITY_NEW_TASK,          // Mandatory for launching from background processes
//     //         Flag.FLAG_ACTIVITY_REORDER_TO_FRONT , // Brings the existing window instance forward if it exists
            
//     //     Flag.FLAG_ACTIVITY_SINGLE_TOP 
//     //       ],
//     //     );
        
//         // This fires the hardware wakeup and forces the app to open visibly on screen!
//         await intent.launch();
//     service.invoke("goToJoinCall");
//   });
// }