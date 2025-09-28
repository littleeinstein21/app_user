import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PickupBookScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const PickupBookScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  Future<void> _recordPickupTransaction(
      BuildContext context, String docId, Map<String, dynamic> book) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('borrows').doc(docId).update({
        'status': 'picked_up',
        'actionType': 'PICKUP',
        'lockerId': 'LKR-01',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ $userName mengambil '${book['bookTitle']}'")),
      );
    } catch (e) {
      print("Error pickup: $e");
    }
  }

  Future<void> _cancelPickupTransaction(
      BuildContext context, String docId, Map<String, dynamic> book) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('borrows').doc(docId).update({
        'status': 'cancelled',
        'actionType': 'CANCEL',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Booking '${book['bookTitle']}' dibatalkan")),
      );
    } catch (e) {
      print("Error cancel: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C54),
      appBar: AppBar(
        title: const Text("Ambil Buku"),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('borrows')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'booked')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("Tidak ada buku untuk diambil",
                  style: TextStyle(color: Colors.white)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                color: const Color(0xFF464577),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(data["bookTitle"] ?? "",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "Oleh ${data["author"]} | Locker: ${data["lockerId"] ?? 'TBD'}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber),
                        onPressed: () =>
                            _recordPickupTransaction(context, doc.id, data),
                        child: const Text("Ambil"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        onPressed: () =>
                            _cancelPickupTransaction(context, doc.id, data),
                        child: const Text("Cancel"),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
