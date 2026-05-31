import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppointmentsScreen extends StatefulWidget {
  final String patientId;
  const AppointmentsScreen({super.key, required this.patientId});
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .collection('appointments')
        .orderBy('dateTime')
        .get();
    setState(() {
      appointments = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _deleteAppointment(String id, int notifId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .collection('appointments')
        .doc(id)
        .delete();
    await AwesomeNotifications().cancel(notifId);
    await _loadAppointments();
  }

  Future<void> _scheduleAppointmentNotification(
      int id, String title, DateTime dt) async {
    final notifTime = dt.subtract(const Duration(hours: 1));
    if (notifTime.isAfter(DateTime.now())) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'appt_channel',
          title: 'Appointment in 1 hour',
          body: title,
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(date: notifTime),
      );
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? existing}) {
    final doctorCtrl =
        TextEditingController(text: existing?['doctor'] ?? '');
    final notesCtrl =
        TextEditingController(text: existing?['notes'] ?? '');
    DateTime selectedDate = existing != null
        ? (existing['dateTime'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay(
        hour: selectedDate.hour, minute: selectedDate.minute);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existing != null
                    ? 'Edit Appointment'
                    : 'Add Appointment',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: doctorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Doctor / Hospital name',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                leading:
                    const Icon(Icons.calendar_today, color: Colors.indigo),
                title: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        selectedTime.hour,
                        selectedTime.minute));
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                leading: const Icon(Icons.access_time,
                    color: Colors.indigo),
                title: Text(
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: selectedTime);
                  if (picked != null) {
                    setModalState(() {
                      selectedTime = picked;
                      selectedDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          picked.hour,
                          picked.minute);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    if (doctorCtrl.text.isEmpty) return;
                    final notifId = selectedDate.millisecondsSinceEpoch
                        .remainder(100000);
                    final data = {
                      'doctor': doctorCtrl.text.trim(),
                      'notes': notesCtrl.text.trim(),
                      'dateTime': Timestamp.fromDate(selectedDate),
                      'notifId': notifId,
                    };
                    if (existing != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.patientId)
                          .collection('appointments')
                          .doc(existing['id'])
                          .update(data);
                    } else {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.patientId)
                          .collection('appointments')
                          .add(data);
                    }
                    await _scheduleAppointmentNotification(
                        notifId, doctorCtrl.text.trim(), selectedDate);
                    if (mounted) Navigator.pop(context);
                    await _loadAppointments();
                  },
                  child: Text(existing != null
                      ? 'Save Changes'
                      : 'Add Appointment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : appointments.isEmpty
              ? const Center(
                  child: Text(
                    'No appointments yet.\nTap + to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: appointments.length,
                  itemBuilder: (_, i) {
                    final a = appointments[i];
                    final dt =
                        (a['dateTime'] as Timestamp).toDate();
                    final isPast = dt.isBefore(DateTime.now());
                    return Card(
                      color: isPast ? Colors.grey.shade50 : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPast
                              ? Colors.grey.shade200
                              : Colors.indigo.shade50,
                          child: Text(
                            '${dt.day}',
                            style: TextStyle(
                              color: isPast
                                  ? Colors.grey
                                  : Colors.indigo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(a['doctor'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                          '${a['notes'] != null && a['notes'].toString().isNotEmpty ? '\n${a['notes']}' : ''}',
                        ),
                        isThreeLine:
                            a['notes'] != null &&
                                a['notes'].toString().isNotEmpty,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.indigo),
                              onPressed: () =>
                                  _showAddEditDialog(existing: a),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _deleteAppointment(
                                  a['id'], a['notifId'] ?? 0),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        label: const Text('Add Appointment'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}