import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/glass_container.dart';
import '../main_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(String method) async {
    setState(() => _isLoading = true);
    
    // Simulate Network Delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock Success
    await StorageService.saveAuthToken("mock_token_123");
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF0f0c29)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // 2. ANIMATED BLOBS
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.3),
                boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.4), blurRadius: 100)],
              ),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.2),
                boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 100)],
              ),
            ),
          ),

          // 3. CONTENT
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20)],
                      ),
                      child: const Icon(CupertinoIcons.circle_grid_hex, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "THINGS OS",
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 3),
                    ),
                    const Text(
                      "Organize your universe.",
                      style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 1),
                    ),
                    
                    const SizedBox(height: 60),

                    if (_isLoading)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      Column(
                        children: [
                          _loginBtn("Continue with Google", CupertinoIcons.globe, () => _handleLogin("google")),
                          const SizedBox(height: 15),
                          _loginBtn("Continue with Apple", CupertinoIcons.device_laptop, () => _handleLogin("apple")),
                          const SizedBox(height: 15),
                          _loginBtn("Use Phone Number", CupertinoIcons.phone, () => _handleLogin("phone")),
                        ],
                      ),
                      
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () {}, 
                      child: const Text("Create an account", style: TextStyle(color: Colors.white70))
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginBtn(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 60,
        borderRadius: 30,
        opacity: 0.1,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 15),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}