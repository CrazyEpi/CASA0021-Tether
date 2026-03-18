import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb; 
import 'package:cloud_firestore/cloud_firestore.dart'; // REQUIRED for Find Friend
import '../main.dart';
import '../models/user.dart'; 
import 'main_nav_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService  = AuthService(); 
  
  bool _obscure   = true;
  bool _loading   = false;
  bool _isSignUp  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // --- THE CRITICAL FIX: Linking Auth to Database ---
  Future<void> _handleAuth() async {
    final email = _emailCtrl.text.trim();
    final pw    = _passwordCtrl.text;

    if (email.isEmpty || pw.isEmpty) { 
      _snack('Please enter email and password'); 
      return; 
    }

    setState(() => _loading = true);
    fb.User? firebaseUser;

    try {
      if (_isSignUp) {
        // 1. Create the user in Firebase Authentication
        firebaseUser = await _authService.signUp(email, pw);
        
        // 2. CREATE FIRESTORE DOCUMENT (This makes "Find Friend" work)
        if (firebaseUser != null) {
          await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
            'username': email.split('@')[0], // Default username from email
            'email': email.toLowerCase(),
            'friendIds': [],
            'isRiding': false,
            'bio': 'New Cyclist',
            'joinDate': FieldValue.serverTimestamp(),
          });
        }
      } else {
        firebaseUser = await _authService.signIn(email, pw);
      }
    } catch (e) {
      _snack('Auth Error: $e', error: true);
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (firebaseUser != null) {
      final currentUser = AppUser(
        id: firebaseUser.uid,
        username: email.split('@')[0], 
        email: email,
        joinDate: DateTime.now(),      
        friendIds: [],                 
        bio: 'New Cyclist',
        avatarUrl: '',
      );

      _snack(_isSignUp ? 'Account created & synced!' : 'Success! Welcome back.');
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainNavScreen(currentUser: currentUser)),
      );
    } else {
      _snack('Authentication failed. Check your details.', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.red : AppTheme.greenDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ---- Logo Section ----
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.pedal_bike, color: Colors.black, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GPP Cycling',
                          style: TextStyle(color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      Text('CASA0021 · UCL',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 52),

              // ---- Headline Section ----
              Text(
                _isSignUp ? 'Create\nAccount' : 'Welcome\nBack 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? 'Join and start tracking rides' : 'Sign in to track your rides',
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),

              const SizedBox(height: 36),

              // ---- Input Fields ----
              _field(_emailCtrl, 'Email', Icons.email_outlined,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 14),

              _field(_passwordCtrl, 'Password', Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppTheme.green.withOpacity(0.5), size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )),

              const SizedBox(height: 12),

              // ---- Info Hint Box ----
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.cloud_done_outlined, color: AppTheme.green, size: 15),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _isSignUp ? 'Password must be 6+ characters' : 'Connected to Firestore DB',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  )),
                ]),
              ),

              const SizedBox(height: 28),

              // ---- Action Button ----
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: AppTheme.black,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                      : Text(_isSignUp ? 'Create Account' : 'Sign In',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp ? 'Already have an account? Log in' : "No account? Sign up",
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // ---- Footer Feature Chips ----
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip(Icons.gps_fixed, 'Live GPS'),
                _chip(Icons.cloud_upload_outlined, 'Cloud Sync'),
                _chip(Icons.flag_outlined, 'Goals'),
                _chip(Icons.leaderboard_outlined, 'Ranks'),
              ]),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // --- Reusable UI Elements ---
  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType? type, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black, 
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.green.withOpacity(0.4)), 
      ),
      child: TextField(
        controller: c,
        keyboardType: type,
        obscureText: obscure,
        cursorColor: AppTheme.green,
        style: const TextStyle(
          color: AppTheme.green, 
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.green.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: AppTheme.green, size: 20), 
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppTheme.green, size: 13),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  );
}