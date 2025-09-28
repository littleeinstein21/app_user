import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  final List<Map<String, dynamic>> history = const [
    {"title": "Atomic Habits", "date": "01/09/2025", "status": "Dipinjam"},
    {"title": "Filosofi Teras", "date": "15/09/2025", "status": "Dikembalikan"},
    {"title": "Sapiens", "date": "20/09/2025", "status": "Dipinjam"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C54),
      appBar: AppBar(
        title: const Text("Riwayat Peminjaman"),
        backgroundColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, i) {
          final item = history[i];
          return Card(
            child: ListTile(
              title: Text(item["title"]),
              subtitle: Text("Tanggal: ${item['date']}"),
              trailing: Text(item["status"]),
            ),
          );
        },
      ),
    );
  }
}
