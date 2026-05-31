import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'appointments_screen.dart';
import 'developers_screen.dart';
import 'dashboard_screen.dart';
import 'add_edit_medicine_screen.dart';
import 'history_screen.dart';
import 'medicine_service.dart';

class CaretakerScreen extends StatefulWidget {
  const CaretakerScreen({super.key});
  @override
  State<CaretakerScreen> createState() => _CaretakerScreenState();
}

class _CaretakerScreenState extends State<CaretakerScreen> {
  String patientId = '';
  String patientName = '';
  String patientBloodGroup = '';
  List<Medicine> medicines = [];
  bool _isLoading = true;
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() => _unreadNotifs = snap.docs.length);
        // fire local notification for each unread
        for (final doc in snap.docs) {
          final data = doc.data();
          AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: doc.id.hashCode.remainder(100000),
              channelKey: 'med_channel',
              title: '⚠️ Patient Alert — ${data['patientName']}',
              body: data['message'] ?? '',
              notificationLayout: NotificationLayout.Default,
            ),
          );
          // mark as read
          doc.reference.update({'read': true});
        }
      }
    });
  }

  Future<void> _loadPatientData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final caretakerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      patientId = caretakerDoc.data()?['patientId'] ?? '';

      if (patientId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();
      patientName = patientDoc.data()?['name'] ?? 'Patient';
      patientBloodGroup =
          patientDoc.data()?['bloodGroup'] ?? 'Unknown';

      final medsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('medicines')
          .get();

      setState(() {
        medicines = medsSnap.docs
            .map((d) => Medicine.fromMap(d.id, d.data()))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
          body:
              'Time for $patientName to take ${med.name} — ${med.dose}',
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

  void _openAddMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditMedicineScreen(
          patientId: patientId,
          onSave: (med) async {
            setState(() => medicines.add(med));
            await MedicineService.addMedicine(
              patientId: patientId,
              med: med,
              scheduleNotif: _scheduleNotifications,
            );
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
          patientId: patientId,
          onSave: (updated) async {
            setState(() => medicines[index] = updated);
            await MedicineService.updateMedicine(
              patientId: patientId,
              med: updated,
              cancelNotifs: _cancelNotifications,
              scheduleNotif: _scheduleNotifications,
            );
          },
        ),
      ),
    );
  }

  void _deleteMedicine(int index) {
    final med = medicines[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Medicine'),
        content:
            Text('Delete ${med.name} from ${patientName}\'s medicines?'),
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
              await MedicineService.deleteMedicine(
                patientId: patientId,
                med: med,
                cancelNotifs: _cancelNotifications,
              );
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

  int get takenCount =>
      medicines.where((m) => m.takenToday).length;

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caretaker Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadPatientData();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'history') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HistoryScreen(
                            patientId: patientId,
                            patientName: patientName)));
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
          : patientId.isEmpty
              ? const Center(
                  child: Text(
                    'No patient linked.\nPlease re-register with a valid patient ID.',
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    // Patient info card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.indigo.shade50,
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          radius: 28,
                          child: Text(
                            patientName.isNotEmpty
                                ? patientName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                                color: Colors.indigo,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(patientName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Row(children: [
                                const Icon(Icons.bloodtype,
                                    color: Colors.red, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Blood Group: $patientBloodGroup',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500),
                                ),
                              ]),
                              Text(
                                '$takenCount of ${medicines.length} medicines taken today',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        // Unread notification badge
                        if (_unreadNotifs > 0)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_unreadNotifs',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ]),
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
                                    'No medicines added yet.',
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
                                          Icon(
                                            m.takenToday
                                                ? Icons.check_circle
                                                : Icons
                                                    .radio_button_unchecked,
                                            color: m.takenToday
                                                ? Colors.teal
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  m.name,
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 15,
                                                    decoration: m
                                                            .takenToday
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
                                                            .grey
                                                            .shade600)),
                                              ],
                                            ),
                                          ),
                                          // Status badge
                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: m.takenToday
                                                  ? Colors.teal.shade50
                                                  : Colors
                                                      .orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      20),
                                            ),
                                            child: Text(
                                              m.takenToday
                                                  ? 'Taken ✅'
                                                  : 'Pending ⏳',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: m.takenToday
                                                      ? Colors.teal
                                                      : Colors.orange,
                                                  fontWeight:
                                                      FontWeight.bold),
                                            ),
                                          ),
                                          // Edit
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.indigo,
                                                size: 20),
                                            onPressed: () =>
                                                _openEditMedicine(i),
                                          ),
                                          // Delete
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 20),
                                            onPressed: () =>
                                                _deleteMedicine(i),
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
                                                        Colors.indigo
                                                            .shade50,
                                                    padding:
                                                        EdgeInsets.zero,
                                                    visualDensity:
                                                        VisualDensity
                                                            .compact,
                                                  ))
                                              .toList(),
                                        ),
                                        const SizedBox(height: 6),

                                        // Course dates
                                        Row(children: [
                                          const Icon(
                                              Icons.calendar_today,
                                              size: 13,
                                              color: Colors.indigo),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Course: ${_formatDate(m.startDate)} → ${_formatDate(m.endDate)}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors
                                                    .grey.shade600),
                                          ),
                                        ]),
                                        const SizedBox(height: 4),

                                        // Stock
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
                                                    : Colors
                                                        .grey.shade600,
                                                fontWeight: m.isLowStock
                                                    ? FontWeight.bold
                                                    : FontWeight.normal),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(
                                              Icons.timer_outlined,
                                              size: 13,
                                              color: Colors.orange),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${m.daysRemaining} days left',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors
                                                    .grey.shade600),
                                          ),
                                        ]),

                                        // Low stock warning
                                        if (m.isLowStock) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
                                              border: Border.all(
                                                  color: Colors
                                                      .red.shade200),
                                            ),
                                            child: Row(children: [
                                              const Icon(Icons.warning,
                                                  color: Colors.red,
                                                  size: 16),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '⚠️ Low stock! Only ${m.quantity} tablets left.',
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
                                            margin:
                                                const EdgeInsets.only(
                                                    top: 6),
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 10,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
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

                    // Bottom buttons
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                            ),
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Appointments'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AppointmentsScreen(
                                    patientId: patientId),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
      floatingActionButton: patientId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddMedicine,
              label: const Text('Add Medicine'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
    );
  }
}
