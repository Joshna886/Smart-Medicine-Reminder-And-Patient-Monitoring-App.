import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'dashboard_screen.dart';

class MedicineService {
  static const String _projectId = 'medicine-alert-c585b';
  static const String _clientEmail = 'firebase-adminsdk-fbsvc@medicine-alert-c585b.iam.gserviceaccount.com';
  static const String _privateKey = '''-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDCL8qNUNnM7FuX
LlMJBIb2UxQ2KqMjIHad5m/JRpK9U54kGJ7YmDl99ToFosZ6akSsic8bFEmuog9G
RIjx0NI+MGk+4GZdQ0RMoBpfrM7e9ivNCBFTjgOedvmRP4tlGD+N5HGVHNtnBctw
t3+K7v4ud9Uw+v6wG2gT96qDJ9GEvGcuZkYotTis2TpB1R4F8M2/iJ/kHSxw5dDs
/p08mgDiFGgkQr0ESC/mGkRJ6097Lfm8RRiMh4Hy4tMsKcdkYflLmTkTOF7YPLbM
kna2st5rH4B/hGkgRCpgRfhgQpask8yn47zAr8pPI9qnVSqcBwYIoFM963z9LX0y
A9Kpya7JAgMBAAECggEAKvs9EC53Jv6h/0KHqpVP8jHNZXfmiB3lY2ngEGMIk9Nw
S3kPn82B3DltUFYJLItdC/us1ceVz4ubaeg9j5izEITSptIwljAPbA58B/VODNfc
NhO1EhN7BZY8A0RXbFcDqjqIUYMDpTgJIbfcCTqBFHP9wkusF/rY/KJzIXiszX4q
n8z2O1EVjZzg1XBp9IX29fvBHEdtqHDlJbE7VpkHYThk8bB5mbEeNpQHnEqsVugU
sinCe0pCm0VXR+mOILPlVo5445Bt+vXbAp9Bhm2iBWhSsBQp7otwovt306tAqLqA
tvtrlqzro5v6Wh/YXqZuY2OisVygm4s6dHA7Gn7NSQKBgQD+dRNhf/3U3bvp4bd7
PIIoEyU2s/B9Wp6rFrK8kJymicXDunliIQv0R/LrewL66pGeCwu+XlUvt4qbrgyl
kzzC2HdAbDxHuBZF00UTpQwZAvMg7Rj6aKgZPgVc9otjEGiMKGFw/mQpTAZW28PW
ywOeN3UOO4vcmfYsneupI2aLrwKBgQDDXSyGsmZD0ZzmcoSjuSmMFbvFqZUW//8d
0IlYOLURUEyOkE3wOJFVJFgEMtwtbehbXszpkYp95qLAawEJNhc8H9aN2MOE8P95
rvb6/MVvaHwj2C8utqrw3bTJUAldQmQxnMRJ9Qqt4sF/4CRBPf4Ou9mYAdspgixf
g7R+wFgzBwKBgQCEk7dPW4KDQCxCRYp1uScPfjorcEFi7q4w8hiaSrZzxuC1hBju
Wc2Cr2IP8v2wgjrwn0y1GS1FOVoMlvib5EUKOAKaHEqkC3P/WX5qJ9pPxcurYh1b
it/alwfwUbx6FviB3iA24TSKl8PNyZ8V8Jyn+LkSe0/51nX+9SDt9TXenQKBgQC4
xEA+TC9H6ND5aklkBtTydgOW1+H3VLnVWsrqswccjtM46eWsUfOxkKPlpKx0EsR0
1d368PkIRb6bORhLu+qRpJLoqJ+R9dPJI97WVYXs7eaqh+Vnyr80+pnm41lX6FiW
S2uhfq1Q82qKJFRll9nV2XfbubWrNj/9PbTRQ9ymtQKBgQDNeLnI9/q6/q5/qAKm
yr9RQhZgaDItjzYxudIdwkWztW/y4rpY2nO+qN5Lp4We37M9fZTluQ70PRAFZRKe
TVVvvzhU7kEc1QtSTBRYRwT70Y/XozdyuF6NxqTDxZambfw8g2LmUGRrE4lcyKgM
Sn+DjuHwCmswcyLhOARVa7ML9Q==
-----END PRIVATE KEY-----
''';

  static Future<void> addMedicine({
    required String patientId,
    required Medicine med,
    required Function scheduleNotif,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('medicines')
        .doc(med.id)
        .set(med.toMap());
    await scheduleNotif(med);
  }

  static Future<void> updateMedicine({
    required String patientId,
    required Medicine med,
    required Function cancelNotifs,
    required Function scheduleNotif,
  }) async {
    await cancelNotifs(med);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('medicines')
        .doc(med.id)
        .update(med.toMap());
    await scheduleNotif(med);
  }

  static Future<void> deleteMedicine({
    required String patientId,
    required Medicine med,
    required Function cancelNotifs,
  }) async {
    await cancelNotifs(med);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('medicines')
        .doc(med.id)
        .delete();
  }

  static Future<void> logIntake({
    required String patientId,
    required String medicineName,
    required bool taken,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('history')
        .doc('${today}_${medicineName.replaceAll(' ', '_')}');

    await logRef.set({
      'medicineName': medicineName,
      'date': today,
      'taken': taken,
      'timestamp': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }

  static Future<void> notifyCaretaker({
    required String patientId,
    required String patientName,
    required String message,
  }) async {
    try {
      final caretakerSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('patientId', isEqualTo: patientId)
          .where('role', isEqualTo: 'caretaker')
          .get();

      if (caretakerSnap.docs.isEmpty) return;

      final caretakerData = caretakerSnap.docs.first.data();
      final caretakerId = caretakerSnap.docs.first.id;
      final fcmToken = caretakerData['fcmToken'] ?? '';

      // Store notification in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(caretakerId)
          .collection('notifications')
          .add({
        'message': message,
        'patientName': patientName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Send FCM v1 push notification
      if (fcmToken.isNotEmpty) {
        await _sendFCMv1(
          token: fcmToken,
          title: '⚠️ Patient Alert — $patientName',
          body: message,
        );
      }
    } catch (e) {
      // error
    }
  }

  static Future<void> _sendFCMv1({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final accountCredentials =
          ServiceAccountCredentials.fromJson({
        'type': 'service_account',
        'project_id': _projectId,
        'private_key': _privateKey,
        'client_email': _clientEmail,
        'token_uri': 'https://oauth2.googleapis.com/token',
      });

      final scopes = [
        'https://www.googleapis.com/auth/firebase.messaging'
      ];

      final client = await clientViaServiceAccount(
          accountCredentials, scopes);

      final url =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'sound': 'default',
                'channel_id': 'med_channel',
              },
            },
          },
        }),
      );

      client.close();
    } catch (e) {
      // FCM error
    }
  }
}
