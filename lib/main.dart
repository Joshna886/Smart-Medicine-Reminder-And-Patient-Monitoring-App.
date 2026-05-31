import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'caretaker_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      channelKey: 'med_channel',
      title: message.notification?.title ?? '⚠️ Patient Alert',
      body: message.notification?.body ?? '',
      notificationLayout: NotificationLayout.Default,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'med_channel',
        channelName: 'Medicine Reminders',
        channelDescription: 'Reminders to take your medicine',
        importance: NotificationImportance.High,
        defaultColor: Colors.teal,
        ledColor: Colors.teal,
      ),
      NotificationChannel(
        channelKey: 'appt_channel',
        channelName: 'Appointment Reminders',
        channelDescription: 'Reminders for doctor appointments',
        importance: NotificationImportance.High,
        defaultColor: Colors.indigo,
        ledColor: Colors.indigo,
      ),
    ],
    debug: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicine Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (token != null && user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    }

    messaging.onTokenRefresh.listen((newToken) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': newToken});
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'med_channel',
          title: message.notification?.title ?? '⚠️ Alert',
          body: message.notification?.body ?? '',
          notificationLayout: NotificationLayout.Default,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Loading...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Colors.teal),
                ),
              );
            }

            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const LoginScreen();
            }

            final role =
                (userSnap.data!.data() as Map<String, dynamic>)['role'] ??
                    'patient';

            _saveFCMToken(snapshot.data!.uid);

            if (role == 'caretaker') {
              return const CaretakerScreen();
            } else {
              return const DashboardScreen();
            }
          },
        );
      },
    );
  }

  Future<void> _saveFCMToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      // offline
    }
  }
}
