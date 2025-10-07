import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/dummy_books.dart'; // <-- pastikan path benar
import '../widgets/book_card.dart'; // <-- BookCard(title, author, status, onPressed)

class BorrowBookScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;

  const BorrowBookScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
  });

  @override
  State<BorrowBookScreen> createState() => _BorrowBookScreenState();
}

class _BorrowBookScreenState extends State<BorrowBookScreen> {
  final TextEditingController searchController = TextEditingController();
  DateTime? selectedDate;
  String _searchQuery = "";

  Future<void> _recordBorrowTransaction(Map<String, dynamic> book) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('borrows').add({
        'userId': widget.userId,
        'userName': widget.userName,
        'userEmail': widget.userEmail,
        'userPhone': widget.userPhone,
        'bookTitle': book['title'],
        'author': book['author'],
        'borrowDate': Timestamp.fromDate(selectedDate ?? DateTime.now()),
        'status': 'booked',
        'actionType': 'BORROW_REQUEST',
        'lockerId': 'TBD',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Berhasil memesan: ${book['title']}")),
      );
    } catch (e) {
      print("Error recording borrow transaction: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mencatat peminjaman: ${e.toString()}")),
      );
    }
  }

  Stream<QuerySnapshot> _getBorrowsStream() {
    return FirebaseFirestore.instance.collection('borrows').snapshots();
  }

  @override
  Widget build(BuildContext context) {
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
                      final title = data['bookTitle'] as String?;

                      if (title != null &&
                          status != 'returned' &&
                          status != 'cancelled') {
                        unavailableTitles.add(title);
                      }
                    }
                  }

                  // Filter buku yang tersisa (tidak di-unavailableTitles)
                  final availableBooks = filteredBooks
                      .where((book) =>
                          !unavailableTitles.contains(book["title"]))
                      .toList();

                  if (availableBooks.isEmpty) {
                    return const Center(
                      child: Text(
                        "📚 Tidak ada buku yang tersedia saat ini.",
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: availableBooks.length,
                    itemBuilder: (context, i) {
                      final book = availableBooks[i];
                      return BookCard(
                        title: book["title"],
                        author: book["author"],
                        status: "Available",
                        onPressed: () => _selectDateAndConfirm(book),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () async {
                Navigator.pop(ctx);
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
