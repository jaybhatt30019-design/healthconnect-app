import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Correct package imports (based on your structure)
import 'package:healthconnect/screens/add_parent_screen.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 🔥 LOGIN FUNCTION
  Future<void> loginUser(BuildContext context) async {
    print("LOGIN FUNCTION STARTED");
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email & password")),
      );
      return;
    }

    try {
      // 🔐 Firebase Auth Login
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: email,
              password: password,
          );

      final uid = userCredential.user!.uid;

      // 🔥 Fetch Firestore Data
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        throw Exception("User data not found");
      }

      final data = doc.data()!;
      final role = data['role'];

      // 🎯 ROLE BASED REDIRECTION
      if (role == 'caregiver') {
  final isLinked = data['parentLinked'] ?? false;

  if (!isLinked) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AddParentScreen(),
      ),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MainDashboard(isCaregiver: true),
      ),
    );
  }

} else if (role == 'parent') {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const MainDashboard(isCaregiver: false),
    ),
  );
}

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE0F7FA),
              Color(0xFFFFF3E0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    color: Color(0xFF004D40),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(height: 40),

                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(35),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 34,
                    color: Color(0xFF00796B),
                  ),
                ),

                const SizedBox(height: 25),

                Text(
                  "Welcome Back",
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004D40),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Login to continue",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Color(0xFF546E7A),
                  ),
                ),

                const SizedBox(height: 50),

                /// EMAIL FIELD
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: "Email Address",
                    prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF00796B)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// PASSWORD FIELD
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF00796B)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                /// LOGIN BUTTON
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF00796B),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextButton(
                    onPressed: () {
  print("BUTTON CLICKED");
  loginUser(context);
},
                    child: Text(
                      "Login",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}