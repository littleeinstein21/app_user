import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PickupBookScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const PickupBookScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<PickupBookScreen> createState() => _PickupBookScreenState();
}

class _PickupBookScreenState extends State<PickupBookScreen> {
  String? _otp;
  Timer? _otpTimer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }

  /// 🔹 Generate OTP acak 4 digit
  Future<void> _generateOTP() async {
    final random = Random();
    final otp = (random.nextInt(9000) + 1000).toString(); // 4 digit random

    setState(() {
      _otp = otp;
      _remainingSeconds = 300; // 5 menit
    });

    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _invalidateOTP();
      }
    });
  }

  /// 🔹 Hapus OTP
  void _invalidateOTP() {
    setState(() {
      _otp = null;
      _remainingSeconds = 0;
    });
    _otpTimer?.cancel();
  }

  /// 🔹 Format waktu countdown
  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  /// 🔹 Catat pengambilan buku
  Future<void> _recordPickupTransaction(
      BuildContext context, String docId, Map<String, dynamic> book) async {
    try {
      await FirebaseFirestore.instance.collection('borrows').doc(docId).update({
        'status': 'picked_up',
        'actionType': 'PICKUP',
        'lockerId': 'LKR-01',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _invalidateOTP();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ ${widget.userName} mengambil '${book['bookTitle']}'")),
      );
    } catch (e) {
      debugPrint("Error pickup: $e");
    }
  }

  /// 🔹 Batalkan peminjaman
  Future<void> _cancelPickupTransaction(
      BuildContext context, String docId, Map<String, dynamic> book) async {
    try {
      await FirebaseFirestore.instance.collection('borrows').doc(docId).update({
        'status': 'cancelled',
        'actionType': 'CANCEL',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Booking '${book['bookTitle']}' dibatalkan")),
      );
    } catch (e) {
      debugPrint("Error cancel: $e");
    }
  }

  /// 🔹 Verifikasi ISBN sebelum pengambilan
  Future<void> _verifyAndPickup(
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
              "Masukkan kode ISBN buku untuk konfirmasi pengambilan:",
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
            child:
                const Text("Batal", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () async {
              final enteredISBN = isbnController.text.trim();
              final correctISBN = (book['isbn'] ?? '').toString();

              if (enteredISBN == correctISBN) {
                Navigator.pop(context);
                await _recordPickupTransaction(context, docId, book);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("❌ ISBN tidak cocok. Coba lagi."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child:
                const Text("Konfirmasi", style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF035C44),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Ambil Buku",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('borrows')
                  .where('userId', isEqualTo: widget.userId)
                  .where('status', isEqualTo: 'booked')
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
                      "Tidak ada buku untuk diambil",
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
                      margin: const EdgeInsets.only(bottom: 12),
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
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("Oleh ${data["author"] ?? "-"}",
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            Text("📍 Lokasi: ${data["pickupLocation"] ?? '-'}",
                                style: const TextStyle(color: Colors.white70)),
                            if (data["pickupMapLink"] != null)
                              GestureDetector(
                                onTap: () async {
                                  final Uri uri =
                                      Uri.parse(data["pickupMapLink"]);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                child: const Text(
                                  "Lihat di Google Maps",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _otp == null
                                        ? Colors.grey
                                        : Colors.amber,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _otp == null
                                      ? null
                                      : () => _verifyAndPickup(
                                            context,
                                            doc.id,
                                            data,
                                          ),
                                  child: const Text("Ambil"),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _cancelPickupTransaction(
                                      context, doc.id, data),
                                  child: const Text("Cancel"),
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

          // 🔹 OTP Section
          if (_otp != null) ...[
            Text(
              "Kode OTP Anda:",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _otp!,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "OTP berlaku selama: ${_formatTime(_remainingSeconds)}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
          ],

          ElevatedButton(
            onPressed: _otp == null ? _generateOTP : _invalidateOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: Text(
              _otp == null ? "Buat OTP Pengambilan" : "Hapus OTP",
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
