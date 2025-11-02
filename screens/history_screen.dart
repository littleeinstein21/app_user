import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const HistoryScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  /// Format tanggal
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "-";
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(date);
  }

  /// Warna status
  Color _statusColor(String status) {
    switch (status) {
      case "booked":
        return Colors.blueAccent;
      case "picked_up":
        return Colors.orangeAccent;
      case "returned":
        return Colors.greenAccent;
      case "cancelled":
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  /// Icon status
  IconData _statusIcon(String status) {
    switch (status) {
      case "booked":
        return Icons.schedule;
      case "picked_up":
        return Icons.book_outlined;
      case "returned":
        return Icons.assignment_turned_in;
      case "cancelled":
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF035C44),
      appBar: AppBar(
        title: const Text(
          "Riwayat Peminjaman",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF035C44),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Coba ambil tanpa orderBy dulu agar tetap tampil
        stream: FirebaseFirestore.instance
            .collection('borrows')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amberAccent),
            );
          }

          // Error handling
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Terjadi kesalahan: ${snapshot.error}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // Tidak ada data
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Belum ada riwayat peminjaman buku.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Urutkan manual (kalau updatedAt ada)
          docs.sort((a, b) {
            final at = (a.data() as Map<String, dynamic>)['updatedAt'];
            final bt = (b.data() as Map<String, dynamic>)['updatedAt'];
            if (at is Timestamp && bt is Timestamp) {
              return bt.compareTo(at);
            }
            return 0;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final bookTitle = data['bookTitle'] ?? "Judul Tidak Diketahui";
              final author = data['author'] ?? "Anonim";
              final status = data['status'] ?? "unknown";
              final lockerId = data['lockerId'] ?? "LKR-??";
              final pickupDate = data['pickupDate'] ?? data['createdAt'];
              final returnDate = data['returnDate'];
              final otp = data['otp'] ?? "-";
              final isbn = data['isbn'] ?? "-";

              return Card(
                color: const Color(0xFF464577),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon Status
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _statusIcon(status),
                          color: _statusColor(status),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Detail Buku
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Penulis: $author",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Locker: $lockerId",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "OTP: $otp",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "ISBN: $isbn",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              status == "returned"
                                  ? "Dikembalikan: ${_formatDate(returnDate)}"
                                  : "Dipinjam: ${_formatDate(pickupDate)}",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Status
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              status == "returned"
                                  ? "Dikembalikan"
                                  : status == "picked_up"
                                      ? "Dipinjam"
                                      : status == "booked"
                                          ? "Dipesan"
                                          : "Dibatalkan",
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
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
