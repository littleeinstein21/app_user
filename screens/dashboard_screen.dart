import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'; // Import untuk Firestore
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/custom_button.dart';
import 'borrow_book_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'pickup_book_screen.dart';
import 'return_locker_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Timer _timer;
  String _currentTime = "";
  String _userName = "Pengguna"; // Default name
  String _greeting = "Halo"; // Default greeting

  final PageController _pageController = PageController(viewportFraction: 0.7);
  int _currentPage = 0;

  // List rekomendasi buku
  final List<String> recommendedBooks = [
    "Atomic Habits – James Clear",
    "How to Win Friends and Influence People – Dale Carnegie",
    "The 7 Habits of Highly Effective People – Stephen R. Covey",
    "Filosofi Teras – Henry Manampiring",
    "Start With Why – Simon Sinek",
    "Sapiens: A Brief History of Humankind – Yuval Noah Harari",
    "Rich Dad Poor Dad – Robert T. Kiyosaki",
    "Man’s Search for Meaning – Viktor E. Frankl",
    "Think and Grow Rich – Napoleon Hill",
    "Grit: The Power of Passion & Perseverance – Angela Duckworth",
  ];

  Timer? _pageTimer;

  @override
  void initState() {
    super.initState();
    // Panggil fungsi untuk ambil data user saat screen dimuat
    _fetchUserData(); 
    _updateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());

    // Auto-scroll carousel setiap 3 detik
    _pageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.positions.isNotEmpty) {
        if (_currentPage < recommendedBooks.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// 🔹 Ambil data nama dari Firestore
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    // Pastikan user sudah login
    if (user == null) return;

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists) {
        // 💡 PERBAIKAN: Mengambil field 'nama' dari Firestore sesuai database Anda
        final nameFromDb = docSnapshot.data()?['nama'] as String?;
        
        if (nameFromDb != null && nameFromDb.isNotEmpty) {
          // Ambil kata pertama saja untuk sapaan
          final firstName = nameFromDb.split(' ').first;
          setState(() {
            _userName = firstName;
          });
        }
      }
    } catch (e) {
      // Tampilkan error jika gagal fetching, tapi aplikasi tetap jalan
      print("Error fetching user data: $e"); 
    }
    // Update greeting setelah mencoba mendapatkan nama
    _setGreeting();
  }

  /// 🔹 Menentukan sapaan berdasarkan waktu (Pagi, Siang, Sore, Malam)
  String _getGreetingText(int hour) {
    if (hour >= 4 && hour < 11) {
      return "Selamat Pagi";
    } else if (hour >= 11 && hour < 15) {
      return "Selamat Siang";
    } else if (hour >= 15 && hour < 19) {
      return "Selamat Sore";
    } else {
      return "Selamat Malam";
    }
  }

  /// 🔹 Mengatur waktu dan sapaan
  void _setGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    final greetingText = _getGreetingText(hour);
    setState(() {
      _greeting = greetingText;
    });
  }


  void _updateTime() {
    final now = DateTime.now();
    final formattedTime = DateFormat('HH:mm:ss').format(now);
    
    // Panggil _setGreeting setiap detik untuk memastikan sapaan selalu akurat
    _setGreeting(); 

    setState(() {
      _currentTime = formattedTime;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 🚫 Blokir tombol back HP
      child: Scaffold(
        backgroundColor: const Color(0xFF2C2C54),
        appBar: AppBar(
          automaticallyImplyLeading: false, // 🚫 Hilangkan tombol back
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'BOOK_LOVER',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Jam realtime
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _currentTime,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
              const SizedBox(height: 5), // Jarak antara jam dan sapaan

              // 💡 Sapaan yang dipersonalisasi
              Text(
                "$_greeting, $_userName!",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 15),

              // Icon besar aplikasi
              const Center(
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 90,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(height: 20),

              // Carousel rekomendasi buku
              SizedBox(
                height: 140,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: recommendedBooks.length,
                  itemBuilder: (context, index) {
                    bool active = index == _currentPage;
                    return _buildBookCard(recommendedBooks[index], active);
                  },
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                ),
              ),
              const SizedBox(height: 25),

              // Tombol sesuai desain
              Expanded(
                child: Column(
                  children: [
                    // Tombol besar
                    CustomButton(
                      text: "Ambil Buku",
                      backgroundColor: Colors.grey,
                      textColor: Colors.black,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PickupBookScreen(userId: '', userName: '',)),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: "Kembalikan Buku",
                      backgroundColor: Colors.grey,
                      textColor: Colors.black,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ReturnLockerScreen(userId: '', userName: '',)),
                        );
                      },
                    ),
                    const SizedBox(height: 25),

                    // Tombol kecil bawah
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _smallMenuButton(
                          context,
                          "Pinjam Buku",
                          Icons.menu_book,
                          const BorrowBookScreen(userId: '', userName: '', userEmail: '', userPhone: '',),
                        ),
                        _smallMenuButton(
                          context,
                          "Riwayat",
                          Icons.history,
                          const HistoryScreen(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookCard(String title, bool active) {
    final double margin = active ? 10 : 20;
    final double scale = active ? 1.0 : 0.9;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: margin, vertical: 10),
      transform: Matrix4.identity()..scale(scale),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF464577), Color(0xFF2C2C54)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: active
            ? [
                const BoxShadow(
                  color: Colors.black38,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                )
              ]
            : [],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.0,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallMenuButton(
      BuildContext context, String title, IconData icon, Widget page) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.white),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
