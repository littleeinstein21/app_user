import 'package:cloud_firestore/cloud_firestore.dart'; // 💡 Import Firestore
import 'package:flutter/material.dart';

import '../data/dummy_books.dart'; // Asumsi: berisi List<Map<String, dynamic>> dummyBooks
import '../widgets/book_card.dart'; // Asumsi: menerima title, author, status, dan onPressed

class BorrowBookScreen extends StatefulWidget {
  // 💡 Tambahkan parameter untuk User ID, Nama, Email, dan Phone
  final String userId;
  final String userName;
  final String userEmail; // Tambahkan Email
  final String userPhone; // Tambahkan Phone

  const BorrowBookScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail, // Wajib diisi
    required this.userPhone, // Wajib diisi
  });

  @override
  State<BorrowBookScreen> createState() => _BorrowBookScreenState();
}

class _BorrowBookScreenState extends State<BorrowBookScreen> {
  final TextEditingController searchController = TextEditingController();
  DateTime? selectedDate;
  String _searchQuery = "";

  // 💡 Fungsi untuk mencatat transaksi peminjaman (Booking) ke Firestore
  Future<void> _recordBorrowTransaction(Map<String, dynamic> book) async {
    try {
      final firestore = FirebaseFirestore.instance;
      // Gunakan koleksi 'borrows' untuk menyimpan transaksi pemesanan
      await firestore.collection('borrows').add({
        'userId': widget.userId,
        'userName': widget.userName,
        // 💡 Tambahkan data kontak pengguna: Email dan Phone
        'userEmail': widget.userEmail,
        'userPhone': widget.userPhone,

        'bookTitle': book['title'],
        'author': book['author'],
        'borrowDate':
            Timestamp.fromDate(selectedDate ?? DateTime.now()), // Waktu pemesanan
        'status': 'booked', // Status awal: dipesan
        'actionType': 'BORROW_REQUEST',
        'lockerId': 'TBD', // To Be Determined
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Tampilkan notifikasi sukses
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "✅ Berhasil memesan: ${book['title']}. Segera ambil di loker!")),
      );
    } catch (e) {
      print("Error recording borrow transaction: $e");
      // Tampilkan notifikasi error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Gagal mencatat peminjaman. Coba lagi. Error: ${e.toString()}")),
      );
    }
  }

  // Fungsi untuk mendapatkan stream data peminjaman dari Firestore
  Stream<QuerySnapshot> _getBorrowsStream() {
    return FirebaseFirestore.instance.collection('borrows').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // Filter buku berdasarkan kueri pencarian
    final filteredBooks = dummyBooks
        .where((book) =>
            book["title"].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF2C2C54),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Peminjaman Buku"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Cari buku...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 16),
            // 💡 Gunakan StreamBuilder untuk mendengarkan status buku secara real-time
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getBorrowsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.amber));
                  }

                  if (snapshot.hasError) {
                    return Center(
                        child: Text("Error: ${snapshot.error}",
                            style: const TextStyle(color: Colors.red)));
                  }

                  // Kumpulkan judul buku yang sedang dipinjam/dipesan
                  final unavailableTitles = <String>{};
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] as String?;

                      // Buku dianggap TIDAK tersedia jika status BUKAN 'returned' atau 'cancelled'
                      if (status != 'returned' && status != 'cancelled') {
                        final title = data['bookTitle'] as String?;
                        if (title != null) {
                          unavailableTitles.add(title);
                        }
                      }
                    }
                  }

                  return ListView.builder(
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, i) {
                      final book = filteredBooks[i];
                      final bookTitle = book["title"] as String;

                      // Tentukan status ketersediaan berdasarkan data Firestore
                      final isAvailable =
                          !unavailableTitles.contains(bookTitle);
                      final currentStatus =
                          isAvailable ? 'Available' : 'Booked';

                      return BookCard(
                        title: bookTitle,
                        author: book["author"],
                        status: currentStatus, // Menampilkan status real-time
                        // Nonaktifkan tombol jika buku tidak tersedia
                        onPressed: isAvailable
                            ? () => _selectDateAndConfirm(book)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi ini hanya dipanggil JIKA buku tersedia
  Future<void> _selectDateAndConfirm(Map<String, dynamic> book) async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF464577),
              onPrimary: Colors.white,
              surface: Color(0xFF2C2C54),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF2C2C54),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF464577),
          title: const Text("Konfirmasi Peminjaman",
              style: TextStyle(color: Colors.white)),
          content: Text(
              "Anda akan memesan buku \"${book['title']}\" (Oleh ${book['author']}). "
              "Silakan ambil buku ini sebelum tanggal ${picked.day}/${picked.month}/${picked.year}.",
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal",
                    style: TextStyle(color: Colors.redAccent))),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () async {
                Navigator.pop(ctx);
                // Panggil fungsi simpan ke Firestore
                await _recordBorrowTransaction(book);
              },
              child: const Text("Konfirmasi"),
            ),
          ],
        ),
      );
    }
  }
}
