import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? existing; // null = add, non-null = edit
  final String patientId;
  final Function(Medicine) onSave;

  const AddEditMedicineScreen({
    super.key,
    this.existing,
    required this.patientId,
    required this.onSave,
  });

  @override
  State<AddEditMedicineScreen> createState() =>
      _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState
    extends State<AddEditMedicineScreen> {
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  String _durationUnit = 'days';

  Map<String, TimeOfDay?> _timings = {
    'Morning': const TimeOfDay(hour: 8, minute: 0),
    'Afternoon': const TimeOfDay(hour: 13, minute: 0),
    'Evening': const TimeOfDay(hour: 18, minute: 0),
    'Night': const TimeOfDay(hour: 21, minute: 0),
  };

  Map<String, bool> _timingEnabled = {
    'Morning': true,
    'Afternoon': false,
    'Evening': false,
    'Night': true,
  };

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final m = widget.existing!;
      _nameCtrl.text = m.name;
      _doseCtrl.text = m.dose;
      _quantityCtrl.text = m.quantity.toString();
      _durationCtrl.text = m.courseDays.toString();
      _durationUnit = 'days';

      // reset all to false first
      _timingEnabled = {
        'Morning': false,
        'Afternoon': false,
        'Evening': false,
        'Night': false,
      };

      // set existing timings
      for (final t in m.timings) {
        _timingEnabled[t.label] = true;
        _timings[t.label] = TimeOfDay(hour: t.hour, minute: t.minute);
      }
    }
  }

  Future<void> _pickTime(String label) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timings[label] ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _timings[label] = picked);
  }

  void _save() {
    if (_nameCtrl.text.isEmpty ||
        _quantityCtrl.text.isEmpty ||
        _durationCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final List<DoseTiming> timings = [];
    for (final label in ['Morning', 'Afternoon', 'Evening', 'Night']) {
      if (_timingEnabled[label] == true && _timings[label] != null) {
        timings.add(DoseTiming(
          label: label,
          hour: _timings[label]!.hour,
          minute: _timings[label]!.minute,
        ));
      }
    }

    if (timings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one timing')),
      );
      return;
    }

    int durationInDays = int.tryParse(_durationCtrl.text) ?? 30;
    if (_durationUnit == 'months') {
      durationInDays = durationInDays * 30;
    }

    final now = DateTime.now();
    final notifId = isEditing
        ? widget.existing!.notifId
        : now.millisecondsSinceEpoch.remainder(100000);

    final med = Medicine(
      id: isEditing
          ? widget.existing!.id
          : now.millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      dose: _doseCtrl.text.isEmpty ? '1 tablet' : _doseCtrl.text.trim(),
      timings: timings,
      notifId: notifId,
      quantity: int.tryParse(_quantityCtrl.text) ?? 0,
      pillsPerDay: timings.length,
      courseDays: durationInDays,
      startDate: isEditing ? widget.existing!.startDate : now,
      endDate: isEditing
          ? widget.existing!.startDate.add(Duration(days: durationInDays))
          : now.add(Duration(days: durationInDays)),
    );

    widget.onSave(med);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medicine' : 'Add Medicine'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine name
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Medicine name',
                prefixIcon: Icon(Icons.medication),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Dose
            TextField(
              controller: _doseCtrl,
              decoration: const InputDecoration(
                labelText: 'Dose per intake (e.g. 1 tablet, 5ml)',
                prefixIcon: Icon(Icons.colorize),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Quantity
            TextField(
              controller: _quantityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total quantity in stock',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Course duration
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Course duration',
                    prefixIcon: Icon(Icons.calendar_month),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _durationUnit,
                  underline: const SizedBox(),
                  items: ['days', 'months'].map((u) {
                    return DropdownMenuItem(
                        value: u, child: Text(u));
                  }).toList(),
                  onChanged: (v) =>
                      setState(() => _durationUnit = v!),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Timings
            const Text(
              'Dose Timings',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            ...['Morning', 'Afternoon', 'Evening', 'Night']
                .map((label) {
              final icons = {
                'Morning': Icons.wb_sunny,
                'Afternoon': Icons.wb_cloudy,
                'Evening': Icons.nights_stay_outlined,
                'Night': Icons.nightlight_round,
              };
              final colors = {
                'Morning': Colors.orange,
                'Afternoon': Colors.blue,
                'Evening': Colors.purple,
                'Night': Colors.indigo,
              };
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _timingEnabled[label] == true
                      ? colors[label]!.withOpacity(0.05)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _timingEnabled[label] == true
                        ? colors[label]!.withOpacity(0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: CheckboxListTile(
                  value: _timingEnabled[label],
                  onChanged: (v) =>
                      setState(() => _timingEnabled[label] = v!),
                  activeColor: colors[label],
                  title: Row(children: [
                    Icon(icons[label],
                        size: 20, color: colors[label]),
                    const SizedBox(width: 10),
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (_timingEnabled[label] == true)
                      GestureDetector(
                        onTap: () => _pickTime(label),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors[label]!.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    colors[label]!.withOpacity(0.4)),
                          ),
                          child: Text(
                            _timings[label] != null
                                ? '${_timings[label]!.hour.toString().padLeft(2, '0')}:${_timings[label]!.minute.toString().padLeft(2, '0')}'
                                : 'Set time',
                            style: TextStyle(
                                color: colors[label],
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ]),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _save,
                child: Text(
                  isEditing
                      ? 'Update Medicine'
                      : 'Save & Set Reminders',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}