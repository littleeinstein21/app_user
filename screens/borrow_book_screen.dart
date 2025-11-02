import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/dummy_books.dart';
import '../widgets/book_card.dart';

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
  String? selectedLocation;

  final Map<String, String> pickupLocations = {
    "BINUS Bekasi": "https://share.google/qOkdAjDKDpX4WZKQL",
    "BINUS Anggrek": "https://share.google/2ykbEiaCojOuXk57g",
  };

  // 🔹 Generate OTP 4 digit
  String _generateOTP() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  // 🔹 Simpan transaksi peminjaman ke Firestore
  Future<void> _recordBorrowTransaction(Map<String, dynamic> book) async {
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Harap pilih lokasi pengambilan terlebih dahulu."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final otpCode = _generateOTP();

      // Tentukan tanggal kadaluarsa OTP = min(5 menit, 1 hari dari tanggal peminjaman)
      final DateTime now = DateTime.now();
      final DateTime otpExpiry = (selectedDate ?? now).isAfter(now.add(const Duration(days: 1)))
          ? now.add(const Duration(days: 1))
          : (selectedDate ?? now);

      await firestore.collection('borrows').add({
        'userId': widget.userId,
        'userName': widget.userName,
        'userEmail': widget.userEmail,
        'userPhone': widget.userPhone,
        'bookTitle': book['title'],
        'author': book['author'],
        'isbn': book['isbn'],
        'borrowDate': Timestamp.fromDate(selectedDate ?? DateTime.now()),
        'status': 'booked',
        'actionType': 'BORROW_REQUEST',
        'lockerId': 'TBD',
        'pickupLocation': selectedLocation,
        'pickupMapLink': pickupLocations[selectedLocation],
        'otp': otpCode,
        'otpGeneratedAt': FieldValue.serverTimestamp(),
        'otpExpiry': Timestamp.fromDate(otpExpiry.add(const Duration(minutes: 5))), // +5 menit aktif
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
      backgroundColor: const Color.fromARGB(255, 3, 92, 68),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 3, 92, 68),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedLocation,
              dropdownColor: const Color(0xFF035C44),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                labelText: "Pilih lokasi pengambilan",
                labelStyle: const TextStyle(color: Colors.white),
              ),
              items: pickupLocations.keys.map((location) {
                return DropdownMenuItem<String>(
                  value: location,
                  child: Text(location,
                      style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedLocation = value;
                });
              },
            ),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getBorrowsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child:
                            CircularProgressIndicator(color: Colors.amber));
                  }

                  final unavailableTitles = <String>{};
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['bookTitle'] != null &&
                          data['status'] != 'returned' &&
                          data['status'] != 'cancelled') {
                        unavailableTitles.add(data['bookTitle']);
                      }
                    }
                  }

                  final availableBooks = filteredBooks
                      .where((book) =>
                          !unavailableTitles.contains(book["title"]))
                      .toList();

                  if (availableBooks.isEmpty) {
                    return const Center(
                      child: Text("📚 Tidak ada buku tersedia.",
                          style: TextStyle(color: Colors.white70)),
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
      builder: (context, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
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
            "Anda akan memesan buku \"${book['title']}\".\n"
            "Lokasi: ${selectedLocation ?? '-'}\n"
            "Ambil sebelum ${picked.day}/${picked.month}/${picked.year}.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Batal", style: TextStyle(color: Colors.redAccent)),
            ),
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
