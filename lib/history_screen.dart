import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const HistoryScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> history = [];
  bool _isLoading = true;
  String _filterMedicine = 'All';
  List<String> _medicineNames = ['All'];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('history')
          .orderBy('date', descending: true)
          .get();

      final records =
          snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      final names = records
          .map((r) => r['medicineName'].toString())
          .toSet()
          .toList();
      names.sort();

      setState(() {
        history = records;
        _medicineNames = ['All', ...names];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredHistory {
    if (_filterMedicine == 'All') return history;
    return history
        .where((h) => h['medicineName'] == _filterMedicine)
        .toList();
  }

  Map<String, List<Map<String, dynamic>>> get groupedHistory {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final record in filteredHistory) {
      final date = record['date'] ?? '';
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(record);
    }
    return grouped;
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final date = DateTime(dt.year, dt.month, dt.day);
      if (date == today) return 'Today';
      if (date == yesterday) return 'Yesterday';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return dateStr;
    }
  }

  int get takenCount =>
      filteredHistory.where((h) => h['taken'] == true).length;

  int get missedCount =>
      filteredHistory.where((h) => h['taken'] == false).length;

  double get adherenceRate {
    if (filteredHistory.isEmpty) return 0;
    return (takenCount / filteredHistory.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patientName}\'s History'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade50,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _statCard(
                              'Total',
                              '${filteredHistory.length}',
                              Colors.teal),
                          _statCard(
                              'Taken', '$takenCount', Colors.green),
                          _statCard(
                              'Missed', '$missedCount', Colors.red),
                          _statCard(
                              'Adherence',
                              '${adherenceRate.toStringAsFixed(0)}%',
                              Colors.indigo),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: adherenceRate / 100,
                          backgroundColor: Colors.red.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            adherenceRate >= 80
                                ? Colors.green
                                : adherenceRate >= 50
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Medication Adherence Rate',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // Filter
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Filter: ',
                          style: TextStyle(
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _filterMedicine,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: _medicineNames.map((name) {
                              return DropdownMenuItem(
                                  value: name, child: Text(name));
                            }).toList(),
                            onChanged: (v) => setState(
                                () => _filterMedicine = v!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // History list
                Expanded(
                  child: filteredHistory.isEmpty
                      ? const Center(
                          child: Text(
                            'No history yet.\nMedicine intake will be recorded here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          itemCount: groupedHistory.keys.length,
                          itemBuilder: (_, i) {
                            final date =
                                groupedHistory.keys.elementAt(i);
                            final records = groupedHistory[date]!;
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  child: Text(
                                    _formatDate(date),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                                ...records.map((record) {
                                  final taken =
                                      record['taken'] == true;
                                  return Card(
                                    margin: const EdgeInsets.only(
                                        bottom: 6),
                                    color: taken
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: taken
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                        child: Icon(
                                          taken
                                              ? Icons.check
                                              : Icons.close,
                                          color: taken
                                              ? Colors.green
                                              : Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        record['medicineName'] ?? '',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        taken
                                            ? 'Taken ✅'
                                            : 'Missed ❌',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: taken
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      trailing: Text(
                                        date,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                Colors.grey.shade500),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
