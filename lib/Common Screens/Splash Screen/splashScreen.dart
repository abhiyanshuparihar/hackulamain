import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hackula1/Admin%20Screens/Home%20Screen%20Admin/homeScreenAdmin.dart';
import 'package:hackula1/Common%20Screens/Login%20Screen/loginScreen.dart';
import 'package:hackula1/Customer%20Screens/Home%20Screen%20Customer/homeScreenCustomer.dart';
import 'package:hackula1/Distributers%20Screen/Distributer%20Home%20Screen/distributerHomeScreen.dart';
import 'package:hackula1/Manufacturer%20Screens/Manufacturer%20Home%20Screen/manufacturerHomeScreen.dart';
import 'package:hackula1/Merchant%20Screens/Home%20Screen%20Merchant/homeScreenMerchant.dart';
import 'dart:async';
import 'package:hackula1/UI%20Helper/Colors/colors.dart';
import 'package:hackula1/UI%20Helper/Gradients/gradients.dart';
import 'package:hackula1/Warehousing%20Screens/Warehousing%20Home%20Screen/wareHousingHomeScreen.dart';
import 'package:hackula1/WholeSalers%20Screen/WholeSalers%20Home%20Screen/wholeSalersHomeScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  // State to manage loading and errors during authentication
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSplashSequence();
  }

  void _setupAnimations() {
    // Logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _logoRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));

    // Text animations
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
    ));

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  void _startSplashSequence() {
    _logoController.forward();

    Timer(const Duration(milliseconds: 500), () {
      _textController.forward();
    });

    // Check authentication status after animations complete
    Timer(const Duration(milliseconds: 3500), () {
      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _navigateToLogin();
        return;
      }

      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _navigateToLogin();
        return;
      }

      final Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      final String? role = userData?['role'] as String?;

      if (role == null) {
        await FirebaseAuth.instance.signOut();
        _navigateToLogin();
        return;
      }

      _navigateBasedOnRole(role.toLowerCase());

    } catch (e) {
      setState(() {
        _error = 'Authentication error: ${e.toString()}';
        _isLoading = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
    }
  }

  void _navigateBasedOnRole(String role){
    if (!mounted) return;
    String routeName;
    switch (role) {
      case 'admin':
        Navigator.pushReplacement(context,MaterialPageRoute(builder: (context)=>AdminHomeScreen()));
        break;
      case 'customer':
        Navigator.pushReplacement(context,MaterialPageRoute(builder: (context)=>CustomerHomeScreen()));
        break;
      case 'merchant':
        Navigator.pushReplacement(context,MaterialPageRoute(builder: (context)=>MerchantHomeScreen()));
        break;
      case 'manufacturer':
        Navigator.pushReplacement(context,MaterialPageRoute(builder: (context)=>ManufacturerHomeScreen()));
        break;
      case 'warehousing':
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => WareHousingHomeScreen()),
              (Route<dynamic> route) => false,
        );
      case 'wholesaler':
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => WholesalerHomeScreen()),
              (Route<dynamic> route) => false,
        );
      case 'distributer':
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => Distributerhomescreen()),
              (Route<dynamic> route) => false,
        );
      default:
        _navigateToLogin();
        return;
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: MyGradients.blueGradient,
        ),
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotationAnimation.value * 0.5,
                          child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: MyGradients.blueGradient,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: MyColors.blueColor.withOpacity(0.4),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF764BA2).withOpacity(0.2),
                                    blurRadius: 50,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: Image.asset('Assets/Images/bakaya-logo.png')),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                  // Animated app name and tagline
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _textFadeAnimation,
                        child: SlideTransition(
                          position: _textSlideAnimation,
                          child: Column(
                            children: [
                              Text(
                                'BAKAYA',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w200,
                                  color: Colors.white,
                                  letterSpacing: 8,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF667EEA).withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Manages your business with ease',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 60),
                  // Loading indicator based on _isLoading and _error state
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _textFadeAnimation,
                        child: _error != null
                            ? Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.withOpacity(0.8),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Redirecting to login...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                            : Column(
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom branding
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textFadeAnimation,
                    child: Center(
                      child: Text(
                        'Powered by Clusters',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}