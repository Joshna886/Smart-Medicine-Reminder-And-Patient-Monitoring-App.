import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'appointments_screen.dart';
import 'developers_screen.dart';
import 'add_edit_medicine_screen.dart';
import 'history_screen.dart';
import 'medicine_service.dart';

class DoseTiming {
  String label;
  int hour;
  int minute;

  DoseTiming({
    required this.label,
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'hour': hour,
        'minute': minute,
      };

  factory DoseTiming.fromMap(Map<String, dynamic> m) => DoseTiming(
        label: m['label'],
        hour: m['hour'],
        minute: m['minute'],
      );
}

class Medicine {
  String id, name, dose;
  List<DoseTiming> timings;
  bool takenToday;
  int notifId;
  int quantity;
  int pillsPerDay;
  int courseDays;
  DateTime startDate;
  DateTime endDate;

  Medicine({
    required this.id,
    required this.name,
    required this.dose,
    required this.timings,
    required this.notifId,
    required this.quantity,
    required this.pillsPerDay,
    required this.courseDays,
    required this.startDate,
    required this.endDate,
    this.takenToday = false,
  });

  int get daysRemaining =>
      endDate.difference(DateTime.now()).inDays.clamp(0, courseDays);

  int get pillsNeededToFinish => daysRemaining * pillsPerDay;

  bool get isLowStock =>
      quantity < (pillsPerDay * 7) && daysRemaining > 7;

  bool get isCourseComplete => DateTime.now().isAfter(endDate);

  Map<String, dynamic> toMap() => {
        'name': name,
        'dose': dose,
        'timings': timings.map((t) => t.toMap()).toList(),
        'takenToday': takenToday,
        'notifId': notifId,
        'quantity': quantity,
        'pillsPerDay': pillsPerDay,
        'courseDays': courseDays,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };

  factory Medicine.fromMap(String id, Map<String, dynamic> m) =>
      Medicine(
        id: id,
        name: m['name'] ?? '',
        dose: m['dose'] ?? '',
        timings: (m['timings'] as List? ?? [])
            .map((t) => DoseTiming.fromMap(t))
            .toList(),
        takenToday: m['takenToday'] ?? false,
        notifId: m['notifId'] ?? 0,
        quantity: m['quantity'] ?? 0,
        pillsPerDay: m['pillsPerDay'] ?? 1,
        courseDays: m['courseDays'] ?? 30,
        startDate: DateTime.parse(
            m['startDate'] ?? DateTime.now().toIso8601String()),
        endDate: DateTime.parse(
            m['endDate'] ?? DateTime.now().toIso8601String()),
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Medicine> medicines = [];
  String uid = '';
  String userName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _loadData();
  }

  Future<void> _requestPermission() async {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  Future<void> _loadData() async {
    uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      userName = userDoc.data()?['name'] ?? 'Patient';

      final medsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('medicines')
          .get();

      setState(() {
        medicines = medsSnap.docs
            .map((d) => Medicine.fromMap(d.id, d.data()))
            .toList();
        _isLoading = false;
      });
      _resetIfNewDay();
      _checkLowStock();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetIfNewDay() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final lastDate = userDoc.data()?['lastResetDate'] ?? '';
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (lastDate != today) {
        for (var m in medicines) {
          m.takenToday = false;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('medicines')
              .doc(m.id)
              .update({'takenToday': false});
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'lastResetDate': today});
        setState(() {});
      }
    } catch (e) {
      // offline
    }
  }

  Future<void> _checkLowStock() async {
    for (var med in medicines) {
      if (med.isLowStock) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: med.notifId + 9000,
            channelKey: 'med_channel',
            title: '⚠️ Low Stock: ${med.name}',
            body:
                'Only ${med.quantity} tablets left but course runs for ${med.daysRemaining} more days. Please refill!',
            notificationLayout: NotificationLayout.Default,
          ),
        );
        // notify caretaker about low stock
        await MedicineService.notifyCaretaker(
          patientId: uid,
          patientName: userName,
          message:
              '⚠️ Low stock alert: ${med.name} has only ${med.quantity} tablets left for $userName. Please refill!',
        );
      }
    }
  }

  Future<void> _scheduleNotifications(Medicine med) async {
    for (int i = 0; i < med.timings.length; i++) {
      final timing = med.timings[i];
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: med.notifId + i,
          channelKey: 'med_channel',
          title: '💊 ${timing.label} Medicine',
          body: 'Time to take ${med.name} — ${med.dose}',
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar(
          hour: timing.hour,
          minute: timing.minute,
          second: 0,
          repeats: true,
        ),
      );
    }
  }

  Future<void> _cancelNotifications(Medicine med) async {
    for (int i = 0; i < med.timings.length; i++) {
      await AwesomeNotifications().cancel(med.notifId + i);
    }
    await AwesomeNotifications().cancel(med.notifId + 9000);
  }

  void _toggleTaken(int index) async {
    final med = medicines[index];
    final newValue = !med.takenToday;
    setState(() {
      medicines[index].takenToday = newValue;
      if (newValue) {
        medicines[index].quantity =
            (medicines[index].quantity - medicines[index].pillsPerDay)
                .clamp(0, 999999);
      } else {
        medicines[index].quantity += medicines[index].pillsPerDay;
      }
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('medicines')
          .doc(med.id)
          .update({
        'takenToday': newValue,
        'quantity': medicines[index].quantity,
      });

      // log to history
      await MedicineService.logIntake(
        patientId: uid,
        medicineName: med.name,
        taken: newValue,
      );
    } catch (e) {
      // offline
    }

    // notify caretaker if missed
    if (!newValue) {
      await MedicineService.notifyCaretaker(
        patientId: uid,
        patientName: userName,
        message:
            '⚠️ $userName has not taken ${med.name} (${med.dose}) today!',
      );
    }

    _checkLowStock();
  }

  void _openAddMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditMedicineScreen(
          patientId: uid,
          onSave: (med) async {
            setState(() => medicines.add(med));
            try {
              await MedicineService.addMedicine(
                patientId: uid,
                med: med,
                scheduleNotif: _scheduleNotifications,
              );
            } catch (e) {
              // offline
            }
            _checkLowStock();
          },
        ),
      ),
    );
  }

  void _openEditMedicine(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditMedicineScreen(
          existing: medicines[index],
          patientId: uid,
          onSave: (updated) async {
            setState(() => medicines[index] = updated);
            try {
              await MedicineService.updateMedicine(
                patientId: uid,
                med: updated,
                cancelNotifs: _cancelNotifications,
                scheduleNotif: _scheduleNotifications,
              );
            } catch (e) {
              // offline
            }
            _checkLowStock();
          },
        ),
      ),
    );
  }

  void _delete(int index) async {
    final med = medicines[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Medicine'),
        content:
            Text('Are you sure you want to delete ${med.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => medicines.removeAt(index));
              try {
                await MedicineService.deleteMedicine(
                  patientId: uid,
                  med: med,
                  cancelNotifs: _cancelNotifications,
                );
              } catch (e) {
                // offline
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _copyUserId() {
    Clipboard.setData(ClipboardData(text: uid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User ID copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  int get takenCount => medicines.where((m) => m.takenToday).length;

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Alert'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'appointments') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AppointmentsScreen(patientId: uid)));
              } else if (value == 'history') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HistoryScreen(
                            patientId: uid,
                            patientName: userName)));
              } else if (value == 'developers') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DevelopersScreen()));
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'appointments',
                child: Row(children: [
                  Icon(Icons.calendar_month, color: Colors.indigo),
                  SizedBox(width: 10),
                  Text('Appointments'),
                ]),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(children: [
                  Icon(Icons.history, color: Colors.teal),
                  SizedBox(width: 10),
                  Text('Intake History'),
                ]),
              ),
              const PopupMenuItem(
                value: 'developers',
                child: Row(children: [
                  Icon(Icons.people, color: Colors.teal),
                  SizedBox(width: 10),
                  Text('Developers'),
                ]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Logout'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Patient info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $userName 👋',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _copyUserId,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.teal.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.badge_outlined,
                                  size: 14, color: Colors.teal),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'ID: $uid',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy,
                                  size: 14, color: Colors.teal),
                              const SizedBox(width: 4),
                              const Text('Tap to copy',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.teal)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress banner
                if (medicines.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: takenCount == medicines.length
                        ? Colors.teal.shade50
                        : Colors.orange.shade50,
                    child: Row(children: [
                      Icon(
                        takenCount == medicines.length
                            ? Icons.check_circle
                            : Icons.pending_actions,
                        color: takenCount == medicines.length
                            ? Colors.teal
                            : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        takenCount == medicines.length
                            ? 'All medicines taken today!'
                            : '$takenCount of ${medicines.length} medicines taken today',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: takenCount == medicines.length
                              ? Colors.teal.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ]),
                  ),

                // Medicine list
                Expanded(
                  child: medicines.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.medication_outlined,
                                  size: 64,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                'No medicines added yet.\nTap + to add one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: medicines.length,
                          itemBuilder: (_, i) {
                            final m = medicines[i];
                            return Card(
                              color: m.isCourseComplete
                                  ? Colors.grey.shade100
                                  : m.takenToday
                                      ? Colors.teal.shade50
                                      : null,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      // Taken checkbox
                                      GestureDetector(
                                        onTap: m.isCourseComplete
                                            ? null
                                            : () => _toggleTaken(i),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: m.takenToday
                                                ? Colors.teal
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: m.isCourseComplete
                                                  ? Colors.grey
                                                  : m.takenToday
                                                      ? Colors.teal
                                                      : Colors.grey,
                                              width: 2,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    8),
                                          ),
                                          child: m.takenToday
                                              ? const Icon(Icons.check,
                                                  color: Colors.white,
                                                  size: 20)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.name,
                                              style: TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 15,
                                                decoration: m.takenToday
                                                    ? TextDecoration
                                                        .lineThrough
                                                    : null,
                                                color: m.takenToday
                                                    ? Colors.grey
                                                    : null,
                                              ),
                                            ),
                                            Text(m.dose,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors
                                                        .grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      // Edit button
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.teal,
                                            size: 20),
                                        onPressed: () =>
                                            _openEditMedicine(i),
                                      ),
                                      // Delete button
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 20),
                                        onPressed: () => _delete(i),
                                      ),
                                    ]),
                                    const SizedBox(height: 8),

                                    // Timing chips
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: m.timings
                                          .map((t) => Chip(
                                                label: Text(
                                                  '${t.label} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                                  style: const TextStyle(
                                                      fontSize: 11),
                                                ),
                                                backgroundColor:
                                                    Colors.teal.shade50,
                                                padding: EdgeInsets.zero,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 8),

                                    // Course dates
                                    Row(children: [
                                      const Icon(Icons.calendar_today,
                                          size: 13,
                                          color: Colors.indigo),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Course: ${_formatDate(m.startDate)} → ${_formatDate(m.endDate)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.grey.shade600),
                                      ),
                                    ]),
                                    const SizedBox(height: 4),

                                    // Stock + days remaining
                                    Row(children: [
                                      const Icon(Icons.medication,
                                          size: 13,
                                          color: Colors.teal),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Stock: ${m.quantity} tablets',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: m.isLowStock
                                                ? Colors.red
                                                : Colors.grey.shade600,
                                            fontWeight: m.isLowStock
                                                ? FontWeight.bold
                                                : FontWeight.normal),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.timer_outlined,
                                          size: 13,
                                          color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${m.daysRemaining} days left',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.grey.shade600),
                                      ),
                                    ]),

                                    // Low stock warning
                                    if (m.isLowStock) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  Colors.red.shade200),
                                        ),
                                        child: Row(children: [
                                          const Icon(Icons.warning,
                                              color: Colors.red,
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '⚠️ Low stock! Only ${m.quantity} tablets left. Need ${m.pillsNeededToFinish} more to finish course.',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ],

                                    // Course complete
                                    if (m.isCourseComplete)
                                      Container(
                                        margin: const EdgeInsets.only(
                                            top: 6),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '✅ Course completed!',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                              fontWeight:
                                                  FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMedicine,
        label: const Text('Add Medicine'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }
}