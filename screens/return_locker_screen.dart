import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/custom_button.dart';

class ReturnLockerScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const ReturnLockerScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ReturnLockerScreen> createState() => _ReturnLockerScreenState();
}

class _ReturnLockerScreenState extends State<ReturnLockerScreen> {
  String? _otp;
  Timer? _otpTimer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }

  /// 🔹 Generate OTP acak 4 digit (0000–9999)
  Future<void> _generateOTP() async {
    final random = Random();
    final otp = (random.nextInt(9000) + 1000).toString(); // 4 digit random

    setState(() {
      _otp = otp;
      _remainingSeconds = 300; // 5 menit (300 detik)
    });

    await FirebaseFirestore.instance.collection('locker_otps').doc(widget.userId).set({
      'otp': otp,
      'timestamp': FieldValue.serverTimestamp(),
      'expiredAt': DateTime.now().add(const Duration(minutes: 5)),
    });

    // 🔸 Jalankan timer countdown
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _invalidateOTP();
      }
    });
  }

  /// 🔹 Hapus OTP (jika waktu habis atau tombol ditekan)
  Future<void> _invalidateOTP() async {
    await FirebaseFirestore.instance.collection('locker_otps').doc(widget.userId).delete();
    setState(() {
      _otp = null;
      _remainingSeconds = 0;
    });
    _otpTimer?.cancel();
  }

  /// 🔹 Format waktu countdown (MM:SS)
  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  /// 🔹 Verifikasi ISBN sebelum pengembalian
  Future<void> _verifyAndReturn(
      BuildContext context, String docId, Map<String, dynamic> book) async {
    final TextEditingController isbnController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E8B82),
        title: const Text(
          "Verifikasi ISBN",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Masukkan kode ISBN buku sebelum mengembalikan:",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: isbnController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Masukkan ISBN...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white30),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () async {
              final enteredISBN = isbnController.text.trim();
              final correctISBN = (book['isbn'] ?? '').toString();

              if (enteredISBN == correctISBN) {
                Navigator.pop(context);
                await _recordReturnTransaction(context, docId, book);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("❌ ISBN tidak cocok. Coba lagi."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text("Konfirmasi", style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  /// 🔹 Catat pengembalian buku ke Firestore
  Future<void> _recordReturnTransaction(
      BuildContext context, String docId, Map<String, dynamic> book) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('borrows').doc(docId).update({
        'status': 'returned',
        'actionType': 'RETURN',
        'returnDate': FieldValue.serverTimestamp(),
        'lockerIdReturn': 'LKR-01',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _invalidateOTP(); // hapus OTP setelah berhasil return

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Buku '${book['bookTitle']}' berhasil dikembalikan oleh ${widget.userName}",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error recording return transaction: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mencatat pengembalian. Error: ${e.toString()}"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF035C44),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Pengembalian Buku",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('borrows')
                  .where('userId', isEqualTo: widget.userId)
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

                    return Card(
                      color: const Color(0xFF464577),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data["bookTitle"] ?? "",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Oleh ${data["author"] ?? "Anonim"}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.lock, color: Colors.amber, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  "OTP: ${_otp ?? '-'}",
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _verifyAndReturn(context, doc.id, data),
                                  child: const Text("Kembalikan"),
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
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: _otp == null ? "Buat OTP Pengembalian" : "Hapus OTP",
            backgroundColor: Colors.amberAccent,
            textColor: Colors.black,
            onPressed: () {
              if (_otp == null) {
                _generateOTP();
              } else {
                _invalidateOTP();
              }
            },
          ),
          const SizedBox(height: 20),
          if (_otp != null)
            Text(
              "OTP berlaku selama: ${_formatTime(_remainingSeconds)}",
              style: const TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
