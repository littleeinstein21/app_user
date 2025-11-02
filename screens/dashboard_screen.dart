import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../data/dummy_books.dart';
import '../widgets/custom_button.dart';
import 'borrow_book_screen.dart';
import 'history_screen.dart' as history;
import 'home_screen.dart';
import 'pickup_book_screen.dart';
import 'return_locker_screen.dart' as return_screen;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Timer _timer;
  String _currentTime = "";
  String _currentDate = "";
  String _userName = "Pengguna";
  String _greeting = "Halo";
  int _currentPage = 0;

  final PageController _pageController = PageController(viewportFraction: 0.85);
  Timer? _pageTimer;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('id_ID', null);
    _fetchUserData();
    _updateTime();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateTime(),
    );

    _pageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.positions.isNotEmpty) {
        if (_currentPage < dummyBooks.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists) {
        final nameFromDb = docSnapshot.data()?['nama'] as String?;
        if (nameFromDb != null && nameFromDb.isNotEmpty) {
          final firstName = nameFromDb.split(' ').first;
          setState(() => _userName = firstName);
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }

    _setGreeting();
  }

  String _getGreetingText(int hour) {
    if (hour >= 4 && hour < 11) return "Selamat Pagi";
    if (hour >= 11 && hour < 15) return "Selamat Siang";
    if (hour >= 15 && hour < 19) return "Selamat Sore";
    return "Selamat Malam";
  }

  void _setGreeting() {
    final now = DateTime.now();
    final greetingText = _getGreetingText(now.hour);
    setState(() => _greeting = greetingText);
  }

  void _updateTime() {
    final now = DateTime.now();
    final formattedTime = DateFormat('HH:mm').format(now);
    final formattedDate = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(now);
    _setGreeting();

    setState(() {
      _currentTime = formattedTime;
      _currentDate = formattedDate;
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
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    final email = user?.email ?? '';
    final phone = user?.phoneNumber ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF035C44),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "i–Library",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 6),
            child: ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout, color: Colors.white, size: 18),
              label: const Text(
                "Keluar",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔹 Greeting & Time
                Column(
                  children: [
                    Text(
                      "$_greeting, $_userName 👋",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentTime,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Colors.amberAccent,
                      ),
                    ),
                    Text(
                      _currentDate,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                // 🔹 Buku Rekomendasi
                SizedBox(
                  height: constraints.maxHeight * 0.3,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: dummyBooks.length,
                    itemBuilder: (context, index) {
                      bool active = index == _currentPage;
                      final book = dummyBooks[index];
                      return _buildBookCard(book, active);
                    },
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                  ),
                ),

                // 🔹 Tombol utama
                Column(
                  children: [
                    CustomButton(
                      text: "Ambil Buku",
                      backgroundColor: Colors.amberAccent,
                      textColor: Colors.black,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PickupBookScreen(
                              userId: uid,
                              userName: _userName,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: "Kembalikan Buku",
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => return_screen.ReturnLockerScreen(
                              userId: uid,
                              userName: _userName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // 🔹 Tombol kecil di bawah
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _smallMenuButton(
                      context,
                      "Pinjam Buku",
                      Icons.library_add_check_outlined,
                      BorrowBookScreen(
                        userId: uid,
                        userName: _userName,
                        userEmail: email,
                        userPhone: phone,
                      ),
                    ),
                    _smallMenuButton(
                      context,
                      "Riwayat",
                      Icons.history_rounded,
                      history.HistoryScreen(userId: uid, userName: _userName,),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: EdgeInsets.symmetric(horizontal: active ? 8 : 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF48B4A0), Color(0xFF2E8B82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: active
            ? [
                const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                )
              ]
            : [],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book["title"],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book["author"],
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book["synopsis"],
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ],
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Icon(icon, size: 28, color: Colors.amberAccent),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
