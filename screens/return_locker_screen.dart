import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/dummy_books.dart';

class ReturnLockerScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const ReturnLockerScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  /// Fungsi untuk mencatat pengembalian buku ke Firestore
  Future<void> _recordReturnTransaction(
      BuildContext context, Map<String, dynamic> book) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('borrows').add({
        'userId': userId,
        'userName': userName,
        'bookTitle': book['title'],
        'author': book['author'],
        'returnDate': FieldValue.serverTimestamp(),
        'status': 'returned',
        'actionType': 'RETURN',
        'lockerId': 'LKR-01', // contoh ID loker
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("✅ Buku '${book['title']}' berhasil dikembalikan oleh $userName"),
        ),
      );

      print("Return transaction recorded: $userName returned ${book['title']}");
    } catch (e) {
      print("Error recording return transaction: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Gagal mencatat pengembalian. Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C54),
      appBar: AppBar(
        title: const Text("Pengembalian Buku"),
        backgroundColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dummyBooks.length,
        itemBuilder: (context, i) {
          final book = dummyBooks[i];
          return Dismissible(
            key: Key(book['title']),
            direction: DismissDirection.endToStart, // geser ke kiri untuk batal
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.cancel, color: Colors.white),
            ),
            onDismissed: (direction) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        "❌ Pengembalian buku '${book['title']}' dibatalkan")),
              );
            },
            child: Card(
              color: const Color(0xFF464577),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(book["title"],
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("Oleh ${book["author"]}",
                    style: const TextStyle(color: Colors.white70)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    _recordReturnTransaction(context, book);
                  },
                  child: const Text("Kembalikan"),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
