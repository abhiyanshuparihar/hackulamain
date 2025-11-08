import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hackula/Admin%20Screens/Distributers%20Registration%20Page/distributersRegistrationPage.dart';
import 'package:hackula/Admin%20Screens/Manufacturer%20Registration%20Page/registerManufacturer.dart';
import 'package:hackula/Admin%20Screens/Warehousing%20Registration%20Page/wareHousingRegistrationPage.dart';
import 'package:hackula/Admin%20Screens/WholeSalers%20Registration%20Page/wholeSalersRegistrationPage.dart';
import 'package:hackula/Common%20Screens/Login%20Screen/loginScreen.dart';
import 'dart:math' as math;
import 'package:hackula/UI%20Helper/Colors/colors.dart';
import 'package:hackula/UI%20Helper/Gradients/gradients.dart';

class AdminHomeScreen extends StatefulWidget {
  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  final List<Map<String, dynamic>> _registrationOptions = [
    {
      'title': 'Register Manufacturer',
      'icon': Icons.factory,
      'gradient': [Color(0xFF667eea), Color(0xFF764ba2)],
      'description': 'Add new manufacturers to the system',
    },
    {
      'title': 'Register Warehousing',
      'icon': Icons.warehouse,
      'gradient': [Color(0xFF4facfe), Color(0xFF00f2fe)],
      'description': 'Register warehouse facilities',
    },
    {
      'title': 'Register Wholesalers',
      'icon': Icons.store,
      'gradient': [Color(0xFFf093fb), Color(0xFFf5576c)],
      'description': 'Add wholesale partners',
    },
    {
      'title': 'Register Distributers',
      'icon': Icons.local_shipping,
      'gradient': [Color(0xFF30cfd0), Color(0xFF91a7ff)],
      'description': 'Register distribution channels',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _fadeController.forward();
    _slideController.forward();
    _rotateController.repeat();
  }

  Future<void> _signOut() async {
    try{
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (Route<dynamic> route) => false,
      );
    } catch (e){
      print('Error signing out: $e');
    }
  }
  void _navigateToRegistration(String title) {
    HapticFeedback.lightImpact();
    Widget? targetPage;

    switch (title) {
      case 'Register Manufacturer':
        targetPage = ManufacturerRegisterPage();
        break;
      case 'Register Warehousing':
        targetPage = WarehousingRegistrationPage();
        break;
      case 'Register Wholesalers':
        targetPage = WholeSalersRegistrationPage();
        break;
      case 'Register Distributers':
        targetPage = DistributersRegistrationPage();
        break;
    }

    if (targetPage != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetPage!),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 25),
                SlideTransition(
                  position: _slideAnimation,
                  child: _build3DAdminCard(),
                ),
                SizedBox(height: 30),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildRegistrationOptions(),
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Panel',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'BAKAYA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: MyColors.blueColor,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                    (Route<dynamic> route) => false,
              );
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: MyGradients.blueGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.logout,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DAdminCard() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: MyGradients.blueGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: MyColors.blueColor.withOpacity(0.3),
            blurRadius: 30,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...List.generate(5, (index) => _buildFloatingOrb(index)),
          Positioned(
            top: 30,
            left: 30,
            right: 30,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(double.infinity, 220),
                    painter: _3DCardPainter(),
                  ),
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Dashboard',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Manage • Monitor • Control',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            AnimatedBuilder(
                              animation: _rotateController,
                              builder: (context, child) {
                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateY(_rotateAnimation.value * 2 * 3.14159),
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            _build3DFeatureIcon(Icons.people, 'Users'),
                            SizedBox(width: 24),
                            _build3DFeatureIcon(Icons.analytics, 'Analytics'),
                            SizedBox(width: 24),
                            _build3DFeatureIcon(Icons.settings, 'Settings'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFloatingIcon(Icons.factory, Offset(-20, 200), Colors.purple),
          _buildFloatingIcon(Icons.warehouse, Offset(300, 50), Colors.cyan),
          _buildFloatingIcon(Icons.local_shipping, Offset(320, 220), Colors.orange),
        ],
      ),
    );
  }

  Widget _buildFloatingOrb(int index) {
    final positions = [
      Offset(50, 40),
      Offset(250, 30),
      Offset(300, 150),
      Offset(30, 200),
      Offset(150, 250),
    ];

    final sizes = [40.0, 60.0, 35.0, 50.0, 45.0];
    final colors = [
      Colors.white.withOpacity(0.1),
      Colors.white.withOpacity(0.15),
      Colors.white.withOpacity(0.08),
      Colors.white.withOpacity(0.12),
      Colors.white.withOpacity(0.1),
    ];

    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        double animationValue = (_rotateAnimation.value + index * 0.2) % 1.0;
        return Positioned(
          left: positions[index].dx + (20 * animationValue),
          top: positions[index].dy + (10 * animationValue),
          child: Container(
            width: sizes[index],
            height: sizes[index],
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  colors[index],
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _build3DFeatureIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingIcon(IconData icon, Offset position, Color color) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        double floatY = 10 * (0.5 + 0.5 * math.sin(_rotateAnimation.value * 2 * math.pi));
        return Positioned(
          left: position.dx,
          top: position.dy + floatY,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegistrationOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registration Options',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MyColors.blueColor,
          ),
        ),
        SizedBox(height: 16),
        ...List.generate(_registrationOptions.length, (index) {
          final option = _registrationOptions[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _buildRegistrationCard(
              option['title'],
              option['icon'],
              option['gradient'],
              option['description'],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRegistrationCard(
      String title,
      IconData icon,
      List<Color> gradientColors,
      String description,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _navigateToRegistration(title),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: MyGradients.blueGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: MyColors.blueColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _3DCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();

    for (int i = 0; i < 6; i++) {
      double y = i * (size.height / 5);
      path.moveTo(0, y);
      path.lineTo(size.width, y);
    }

    for (int i = 0; i < 8; i++) {
      double x = i * (size.width / 7);
      path.moveTo(x, 0);
      path.lineTo(x, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}