import 'package:flutter/material.dart';

class DevelopersScreen extends StatelessWidget {
  const DevelopersScreen({super.key});

  final List<Map<String, String>> developers = const [
    {
      'name': 'Navami K.S',
      'initials': 'NK',
    },
    {
      'name': 'Joshna Philip',
      'initials': 'JP',
    },
    {
      'name': 'Theertha S Jayakumar',
      'initials': 'TJ',
    },
    {
      'name': 'Naieem Hussain',
      'initials': 'NH',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developers'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Medicine Alert',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.teal.shade400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A healthcare app to improve\nmedication adherence',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PROJECT TEAM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: developers.length,
              itemBuilder: (context, index) {
                final dev = developers[index];
                final colors = [
                  Colors.teal,
                  Colors.indigo,
                  Colors.orange,
                  Colors.pink,
                ];
                final color = colors[index % colors.length];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(
                        dev['initials']!,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    title: Text(
                      dev['name']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: const Text(
                      'Developer',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.code,
                      color: color,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Made with ❤️ for better healthcare',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}