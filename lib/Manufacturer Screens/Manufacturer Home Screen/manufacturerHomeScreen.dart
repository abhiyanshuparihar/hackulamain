import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hackula1/Common%20Screens/Login%20Screen/loginScreen.dart';
import 'package:hackula1/Manufacturer%20Screens/Manufacturer%20Qr%20creation%20and%20download%20feature/qrCreationandDownload.dart';
import 'package:hackula1/Manufacturer%20Screens/Scanning%20Page/scanQr.dart';
import 'package:hackula1/UI%20Helper/Colors/colors.dart';
import 'package:hackula1/UI%20Helper/Gradients/gradients.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ManufacturerHomeScreen extends StatefulWidget {
  const ManufacturerHomeScreen({Key? key}) : super(key: key);

  @override
  State<ManufacturerHomeScreen> createState() => _ManufacturerHomeScreenState();
}

class _ManufacturerHomeScreenState extends State<ManufacturerHomeScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _drawerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _drawerSlideAnimation;

  // Pagination state
  final int _pageSize = 2;
  List<DocumentSnapshot> _documentSnapshots = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String? _currentUserId;
  String _manufacturerName = 'Manufacturer';
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _currentUserId = _auth.currentUser?.uid;
    if (_currentUserId != null) {
      _fetchManufacturerName();
      _loadInitialData();
    } else {
      _isLoading = false;
      _hasMore = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logout(context);
      });
    }
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
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _drawerController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
    _drawerSlideAnimation = Tween<Offset>(
      begin: Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _drawerController, curve: Curves.easeInOut));

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
    _rotateController.repeat();
  }

  Future<void> _fetchManufacturerName() async {
    if (_currentUserId != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUserId).get();
        if (userDoc.exists) {
          setState(() {
            _manufacturerName = (userDoc.data() as Map<String, dynamic>?)?['firstName'] ?? 'Manufacturer';
          });
        }
      } catch (e) {
        print("Error fetching manufacturer name: $e");
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _documentSnapshots.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (!_hasMore || _currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    Query query = _firestore
        .collection('parentQrs')
        .where('manufacturedByUid', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    try {
      final QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        setState(() {
          _documentSnapshots.addAll(snapshot.docs);
          _hasMore = snapshot.docs.length == _pageSize;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching products: $e");
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
    }
  }


  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    _drawerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 10),
                          SlideTransition(
                            position: _slideAnimation,
                            child: _build3DVisualSection(),
                          ),
                          SizedBox(height: 30),
                          SlideTransition(
                            position: _slideAnimation,
                            child: _buildQuickActions(),
                          ),
                          SizedBox(height: 30),
                          SlideTransition(
                            position: _slideAnimation,
                            child: _buildProductHistory(),
                          ),
                          SizedBox(height: 30),
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

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _manufacturerName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: MyColors.blueColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
              height: 50,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: IconButton(onPressed: (){
                FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(context,MaterialPageRoute(builder: (context)=>LoginScreen()));
              }, icon: Icon(Icons.logout))
          ),
        ],
      ),
    );
  }


  Widget _build3DVisualSection() {
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
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Padding(
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
                              'MANUFACTURER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Track • Manage • Produce',
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
                                  Icons.precision_manufacturing,
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
                        _build3DFeatureIcon(Icons.qr_code, 'Generate'),
                        SizedBox(width: 24),
                        _build3DFeatureIcon(Icons.scanner, 'Scan'),
                        SizedBox(width: 24),
                        _build3DFeatureIcon(Icons.history, 'Track'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildFloatingPaymentIcon(Icons.qr_code_2, Offset(-20, 200), Colors.green),
          _buildFloatingPaymentIcon(Icons.scanner, Offset(300, 50), Colors.blue),
          _buildFloatingPaymentIcon(Icons.inventory, Offset(320, 220), Colors.orange),
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
                colors: [colors[index], Colors.transparent],
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
          child: Icon(icon, color: Colors.white, size: 20),
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

  Widget _buildFloatingPaymentIcon(IconData icon, Offset position, Color color) {
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
            child: Icon(icon, color: color, size: 24),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MyColors.blueColor,
          ),
        ),
        SizedBox(height: 16),
        Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                Icons.qr_code_2,
                'Generate QR',
                MyGradients.blueGradient,
                Colors.green,
              ),
              _buildActionButton(
                Icons.scanner,
                'Scan QR',
                MyGradients.blueGradient,
                Colors.blue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, LinearGradient gradient, Color accentColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (label == "Generate QR") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProductQrGeneratorPage()),
          );
        } else if (label == "Scan QR") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProductQRScannerScreen()),
          );
        }
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manufacturing History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MyColors.blueColor,
          ),
        ),
        SizedBox(height: 16),
        if (_documentSnapshots.isEmpty && _isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading products...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_documentSnapshots.isEmpty && !_isLoading)
          Container(
            padding: EdgeInsets.all(40),
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
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No products yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Generate a QR to begin manufacturing',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              ..._documentSnapshots.map((doc) => _buildProductCard(doc)).toList(),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: _isLoading
                      ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
                      strokeWidth: 3,
                    ),
                  )
                      : GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _fetchProducts();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: MyGradients.blueGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: MyColors.blueColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Load More',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.expand_more, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String productName = data['productName'] ?? 'N/A';
    final String mrp = (data['productMRP']?.toString() ?? 'N/A');
    final String expiryDate = data['productDateOfExpiry'] ?? 'N/A';
    final String manufactureDate = data['productDateOfManufacturing'] ?? 'N/A';
    final int quantity = data['quantity'] ?? 0;
    final String status = data['status'] ?? "Not Specified";
    final Timestamp? createdAtTimestamp = data['createdAt'];

    String formattedDate = 'N/A';
    if (createdAtTimestamp != null) {
      formattedDate = DateFormat('dd MMM yyyy').format(createdAtTimestamp.toDate());
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: MyGradients.blueGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: MyColors.blueColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Qty: $quantity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.grey.shade100,
            ),
            SizedBox(height: 16),
            _buildDetailRow(
              icon: Icons.monetization_on,
              label: 'MRP',
              value: '₹$mrp',
              color: Colors.green,
            ),
            SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.calendar_today,
              label: 'Mfd Date',
              value: manufactureDate,
              color: Colors.blue,
            ),
            SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.date_range,
              label: 'Exp Date',
              value: expiryDate,
              color: Colors.orange,
            ),
            SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.signal_wifi_statusbar_4_bar,
              label: 'Status',
              value: status,
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}