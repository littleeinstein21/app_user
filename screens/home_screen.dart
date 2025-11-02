import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  String? selectedFileName;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _onLogin() async {
    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showSnack("Harap isi email & password");
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: password);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _showSnack("Login gagal: ${e.message}");
    }
  }

  Future<void> _selectKtpFile() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        selectedFileName = result.files.single.name;
      });
    }
  }

  bool _validateEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@(gmail\.com|binus\.ac\.id)$');
    return regex.hasMatch(email);
  }

  bool _validatePhone(String phone) {
    final regex = RegExp(r'^[0-9]+$');
    return regex.hasMatch(phone);
  }

  bool _validatePassword(String password) {
    final regex =
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> _onSignup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showSnack("Harap isi semua field");
      return;
    }

    if (!_validateEmail(email)) {
      _showSnack("Email harus @gmail.com atau @binus.ac.id");
      return;
    }

    if (!_validatePhone(phone)) {
      _showSnack("No. Telp hanya boleh angka");
      return;
    }

    if (!_validatePassword(password)) {
      _showSnack(
          "Password minimal 8 karakter dengan huruf besar, kecil, dan angka");
      return;
    }

    if (selectedFileName == null) {
      _showSnack("Harap upload foto KTP");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCred.user?.uid;

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "nama": name,
        "email": email,
        "phone": phone,
        "ktp_file": selectedFileName,
        "created_at": FieldValue.serverTimestamp(),
      });

      await userCred.user?.updateDisplayName(name);
      _showSnack("Akun berhasil dibuat! Silakan login.");
      _tabController.animateTo(0);
    } on FirebaseAuthException catch (e) {
      _showSnack("Gagal daftar: ${e.message}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 3, 92, 68),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.book_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  "i-Library",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Kelola akun Anda",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.tealAccent,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: Colors.tealAccent,
                  indicatorWeight: 2.5,
                  tabs: const [
                    Tab(text: "Login"),
                    Tab(text: "Sign Up"),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 430,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginTab(),
                      _buildSignupTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab() => Column(
        children: [
          CustomTextField(
            controller: loginEmailController,
            hint: "Email",
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email,
            label: 'Email',
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: loginPasswordController,
            hint: "Password",
            isPassword: true,
            prefixIcon: Icons.lock,
            label: 'Password',
          ),
          const SizedBox(height: 24),
          CustomButton(text: "Login", onPressed: _onLogin),
        ],
      );

  Widget _buildSignupTab() => SingleChildScrollView(
        child: Column(
          children: [
            CustomTextField(
              controller: nameController,
              hint: "Nama Lengkap",
              prefixIcon: Icons.person,
              label: 'Nama Lengkap',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: emailController,
              hint: "Email",
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email,
              label: 'Email',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: phoneController,
              hint: "No. Telp/WA",
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixIcon: Icons.phone,
              label: 'No. Telp/WA',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: passwordController,
              hint: "Password",
              isPassword: true,
              prefixIcon: Icons.lock,
              label: 'Password',
            ),
            // const SizedBox(height: 8),
            // TextButton.icon(
            //   onPressed: _selectKtpFile,
            //   icon: const Icon(Icons.upload_file, color: Colors.tealAccent),
            //   label: Text(
            //     selectedFileName ?? "Upload Foto KTP",
            //     style: const TextStyle(color: Colors.white70),
            //   ),
            // ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.tealAccent)
                : CustomButton(text: "Daftar", onPressed: _onSignup),
          ],
        ),
      );
}
