import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReturnLockerScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const ReturnLockerScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  /// Fungsi untuk mengupdate status transaksi menjadi 'returned'
  Future<void> _recordReturnTransaction(
      BuildContext context, String docId, String bookTitle) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('borrows').doc(docId).update({
        'status': 'returned',
        'actionType': 'RETURN',
        'returnDate': FieldValue.serverTimestamp(),
        'lockerIdReturn': 'LKR-01',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Buku '$bookTitle' berhasil dikembalikan oleh $userName",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error recording return transaction: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Gagal mencatat pengembalian. Error: ${e.toString()}"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF2C2C54),
      appBar: AppBar(
        title: const Text("Pengembalian Buku"),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('borrows')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'picked_up')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Tidak ada buku yang sedang Anda pinjam.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final bookTitle = data['bookTitle'] ?? 'Judul Tidak Diketahui';

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.cancel, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  bool? confirm = await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Batalkan Pengembalian"),
                      content: Text(
                          "Apakah kamu yakin ingin membatalkan pengembalian buku '$bookTitle'?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Tidak"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Ya"),
                        ),
                      ],
                    ),
                  );
                  return confirm ?? false;
                },
                onDismissed: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text("❌ Pengembalian buku '$bookTitle' dibatalkan."),
                    ),
                  );
                },
                child: Card(
                  color: const Color(0xFF464577),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      bookTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "Oleh ${data['author'] ?? 'Anonim'} | Pinjam di ${data['lockerId'] ?? 'LKR-??'}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        _recordReturnTransaction(context, doc.id, bookTitle);
                      },
                      child: const Text("Kembalikan"),
                    ),
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
