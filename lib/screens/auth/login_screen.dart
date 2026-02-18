import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_container.dart';
import '../main_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _handleEmailAuth() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text.trim();

      if (email.isEmpty || password.isEmpty) return;

      if (_isSignUp) {
        await AuthService.signUpWithEmail(email, password);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created! Please sign in.')));
           setState(() => _isSignUp = false);
        }
      } else {
        await AuthService.signInWithEmail(email, password);
        // Navigation is handled by auth state listener or directly
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScaffold()));
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithGoogle();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScaffold()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign In Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basic dark theme for login
    final isDark = true; 
    final textColor = Colors.white;
    const secondaryTextColor = Colors.white70;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
             child: Container(
               decoration: const BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topLeft, end: Alignment.bottomRight,
                   colors: [Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF000000)]
                 )
               ),
             ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.black, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text("Things", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  const Text("Organize your entire existence.", style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                  const SizedBox(height: 50),

                  GlassContainer(
                    width: double.infinity,
                    borderRadius: 20,
                    opacity: 0.1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CupertinoTextField(
                            controller: _emailCtrl,
                            placeholder: "Email",
                            placeholderStyle: const TextStyle(color: Colors.white38),
                            style: const TextStyle(color: Colors.white),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 15),
                          CupertinoTextField(
                            controller: _passCtrl,
                            placeholder: "Password",
                             placeholderStyle: const TextStyle(color: Colors.white38),
                            style: const TextStyle(color: Colors.white),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                            obscureText: true,
                          ),
                          const SizedBox(height: 25),

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              onPressed: _isLoading ? null : _handleEmailAuth,
                              child: _isLoading 
                                ? const CupertinoActivityIndicator()
                                : Text(_isSignUp ? "Create Account" : "Sign In", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Toggle Mode
                          GestureDetector(
                            onTap: () => setState(() => _isSignUp = !_isSignUp),
                            child: Text(
                              _isSignUp ? "Already have an account? Sign In" : "New here? Create Account",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Text("OR", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),

                  // Google Button
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      onPressed: _isLoading ? null : _handleGoogleAuth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(CupertinoIcons.globe, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text("Continue with Google", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}