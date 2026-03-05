import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user.dart';
import 'main_nav_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure   = true;
  bool _loading   = false;
  bool _isSignUp  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pw    = _passwordCtrl.text;
    if (email.isEmpty || pw.isEmpty) { _snack('Please enter email and password'); return; }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);
    if (!UserData.isEmailRegistered(email)) {
      _snack('Account not found', error: true);
    } else if (!UserData.verifyUser(email, pw)) {
      _snack('Incorrect password', error: true);
    } else {
      final user = UserData.getUserByEmail(email)!;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => MainNavScreen(currentUser: user)));
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

              // ---- Logo ----
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.pedal_bike, color: Colors.white, size: 26),
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

              // ---- Headline ----
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

              // ---- Email field ----
              _field(_emailCtrl, 'Email', Icons.email_outlined,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 14),

              // ---- Password field ----
              _field(_passwordCtrl, 'Password', Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white38, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )),

              const SizedBox(height: 12),

              // ---- Demo hint ----
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: AppTheme.green, size: 15),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Demo  ·  yidan@ucl.ac.uk  ·  casa2025',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  )),
                ]),
              ),

              const SizedBox(height: 28),

              // ---- Login button ----
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_isSignUp ? () {
                    _snack('Demo mode: use existing account');
                    setState(() => _isSignUp = false);
                  } : _login),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: AppTheme.black,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                      : Text(_isSignUp ? 'Sign Up' : 'Log In',
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

              // ---- Feature chips ----
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip(Icons.gps_fixed, 'Live GPS'),
                _chip(Icons.map_outlined, 'Route Planner'),
                _chip(Icons.flag_outlined, 'Ride Goals'),
                _chip(Icons.leaderboard_outlined, 'Leaderboard'),
                _chip(Icons.people_outline, 'Friends'),
              ]),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType? type, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: c,
        keyboardType: type,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          fillColor: Colors.transparent,
          filled: false,
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
