import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  String? selectedFileName;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  /// 🔹 pilih file KTP
  Future<void> _selectKtpFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        selectedFileName = result.files.single.name;
      });
    }
  }

  /// 🔹 validasi email
  bool _validateEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@(gmail\.com|binus\.ac\.id)$');
    return regex.hasMatch(email);
  }

  /// 🔹 validasi nomor telepon
  bool _validatePhone(String phone) {
    final regex = RegExp(r'^[0-9]+$');
    return regex.hasMatch(phone);
  }

  /// 🔹 validasi password
  bool _validatePassword(String password) {
    final regex =
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{8,}$');
    return regex.hasMatch(password);
  }

  /// 🔹 proses daftar
  Future<void> _onSignup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap isi semua field")),
      );
      return;
    }

    if (!_validateEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Email harus @gmail.com atau @binus.ac.id")),
      );
      return;
    }

    if (!_validatePhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No. Telp/WA hanya boleh angka")),
      );
      return;
    }

    if (!_validatePassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Password minimal 8 karakter dengan huruf besar, kecil, dan angka"),
        ),
      );
      return;
    }

    if (selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap upload foto KTP")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 🔹 1. Buat akun di Firebase Auth
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCred.user?.uid;

      // 🔹 2. Simpan data ke Firestore
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "nama": name,
        "email": email,
        "phone": phone,
        "ktp_file": selectedFileName, // hanya nama file, belum upload storage
        "created_at": FieldValue.serverTimestamp(),
      });

      // 🔹 3. Update nama di Firebase Auth
      await userCred.user?.updateDisplayName(name);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Akun berhasil dibuat! Silakan login.")),
      );

      // 🔹 4. Balik ke HomeScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal daftar: ${e.message}")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C54),
      appBar: AppBar(
        title: const Text("Sign Up"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CustomTextField(controller: nameController, hint: "Nama Lengkap"),
            const SizedBox(height: 20),

            CustomTextField(controller: emailController, hint: "Email"),
            const SizedBox(height: 20),

            TextField(
              controller: phoneController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: "No. Telp/WA",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white10,
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: "Password",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white10,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _selectKtpFile,
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text('Upload Foto KTP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
            ),
            const SizedBox(height: 8),
            if (selectedFileName != null)
              Text(
                "File: $selectedFileName",
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 32),

            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : CustomButton(
                    text: "Daftar",
                    onPressed: _onSignup,
                  ),
          ],
        ),
      ),
    );
  }
}
