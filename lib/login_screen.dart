import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _animations;

  static const Color cobaltBlue = Color(0xFF0047AB);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Create 6 controllers for: logo, title, email button, divider, guest/help buttons
    _controllers = List.generate(
        6, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));

    _animations = _controllers
        .map((c) => Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _controllers[i].forward();
    }
  }

  @override
  void dispose() {
    _controllers.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFE),
      body: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -120,
            left: -120,
            child: _buildCircle(300, const Color(0xFFE0ECF8)),
          ),
          Positioned(
            bottom: -140,
            right: -140,
            child: _buildCircle(280, const Color(0xFFE0ECF8)),
          ),
          Positioned(
            top: -50,
            right: -50,
            child: _buildCircle(120, const Color(0xFFF2F7FC)),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _buildCircle(100, const Color(0xFFF2F7FC)),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  SlideTransition(
                    position: _animations[0],
                    child: Image.asset(
                      'assets/ocr.png',
                      height: 80,
                      width: 80,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Animated Title
                  SlideTransition(
                    position: _animations[1],
                    child: const Text(
                      'OCR',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cobaltBlue,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Animated Email Login Button
                  SlideTransition(
                    position: _animations[2],
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        child: const Text(
                          'Login with Email',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cobaltBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/signin');
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Animated Divider
                  SlideTransition(
                    position: _animations[3],
                    child: const Row(
                      children: [
                        Expanded(
                          child: Divider(
                            thickness: 1,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'or continue with',
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Divider(
                            thickness: 1,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Animated Guest Button
                  SlideTransition(
                    position: _animations[4],
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: cobaltBlue),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/home');
                            },
                            child: const Text(
                              'Guest',
                              style: TextStyle(fontSize: 15, color: cobaltBlue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: cobaltBlue),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/help');
                            },
                            child: const Text(
                              'Help',
                              style: TextStyle(fontSize: 15, color: cobaltBlue),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildCircle(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
