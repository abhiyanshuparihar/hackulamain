import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hackula/Common%20Screens/Login%20Screen/loginScreen.dart';
import 'dart:math' as math;
import 'package:hackula/UI%20Helper/Colors/colors.dart';
import 'package:hackula/UI%20Helper/Gradients/gradients.dart';
import 'package:hackula/Warehousing%20Screens/Scanning%20Qr%20Page/scanningAndSaving.dart';

class ParentProductData {
  final String parentId;
  final double quantity;
  final double productMRP;
  final String status;
  final String productDateOfExpiry;
  final String productDateOfManufacturing;
  final String productName;

  ParentProductData({
    required this.parentId,
    required this.quantity,
    required this.productMRP,
    required this.status,
    required this.productDateOfExpiry,
    required this.productDateOfManufacturing,
    required this.productName,
  });
}

class WareHousingHomeScreen extends StatefulWidget {
  @override
  _WareHousingHomeScreenState createState() => _WareHousingHomeScreenState();
}

class _WareHousingHomeScreenState extends State<WareHousingHomeScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

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

  bool _isDrawerOpen = false;
  String _warehouseName = 'Warehouse';
  final int _pageSize = 2;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchWarehouseName();

    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => LoginScreen()));
      });
    }
  }
  void _initAnimations(){
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
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
    _drawerSlideAnimation = Tween<Offset>(
      begin: Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _drawerController, curve: Curves.easeInOut));

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
    _rotateController.repeat();
  }

  Future<void> _fetchWarehouseName() async {
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(_currentUser!.uid).get();
        if (userDoc.exists) {
          setState(() {
            _warehouseName = (userDoc.data() as Map<String, dynamic>?)?['firstName'] ??
                'Warehouse';
          });
        }
      } catch (e) {
        print("Error fetching warehouse name: $e");
      }
    }
  }

  void _toggleDrawer() {
    setState(() {
      _isDrawerOpen = !_isDrawerOpen;
    });
    if (_isDrawerOpen) {
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
    HapticFeedback.lightImpact();
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
                            child: _buildInventoryStream(),
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
                      _warehouseName,
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
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(onPressed: (){
              FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginScreen()), (Route<dynamic> route) => false);
            },icon:Icon(Icons.logout),color: MyColors.blueColor,)
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
                              'WAREHOUSE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Store • Track • Manage',
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
                                  Icons.inventory_2,
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
                        _build3DFeatureIcon(Icons.qr_code_scanner, 'Scan'),
                        SizedBox(width: 24),
                        _build3DFeatureIcon(Icons.inventory, 'Stock'),
                        SizedBox(width: 24),
                        _build3DFeatureIcon(Icons.local_shipping, 'Ship'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildFloatingPaymentIcon(
              Icons.qr_code_scanner, Offset(-20, 200), Colors.green),
          _buildFloatingPaymentIcon(Icons.inventory_2, Offset(300, 50), Colors.orange),
          _buildFloatingPaymentIcon(Icons.warehouse, Offset(320, 220), Colors.blue),
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

  Widget _buildFloatingPaymentIcon(
      IconData icon, Offset position, Color color) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        double floatY =
            10 * (0.5 + 0.5 * math.sin(_rotateAnimation.value * 2 * math.pi));
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
                Icons.qr_code_scanner,
                'Scan QR',
                MyGradients.blueGradient,
                Colors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildActionButton(
      IconData icon, String label, LinearGradient gradient, Color accentColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => WareHousingQRScannerScreen()),
        );
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

  Widget _buildInventoryStream() {
    if (_currentUser == null) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Warehouse Inventory',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MyColors.blueColor,
          ),
        ),
        SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('parentQrs')
              .where('wareHousingBy', isEqualTo: _currentUser!.uid)
              .orderBy('quantity', descending: true)
              .limit(_pageSize)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState('Error loading inventory: ${snapshot.error}');
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            return FutureBuilder<List<ParentProductData>>(
              future: _processDocuments(snapshot.data!.docs),
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (futureSnapshot.hasError) {
                  return _buildErrorState(
                      'Error processing data: ${futureSnapshot.error}');
                }

                if (!futureSnapshot.hasData || futureSnapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: futureSnapshot.data!
                      .map((data) => _buildInventoryCard(data))
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<List<ParentProductData>> _processDocuments(
      List<QueryDocumentSnapshot> docs) async {
    List<ParentProductData> dataList = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final double quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
      final double productMRP = (data['productMRP'] as num?)?.toDouble() ?? 0.0;
      final String status = data['status'] as String? ?? 'N/A';
      final String productName = data['productName'] as String? ?? 'Unknown Product';

      final List<dynamic>? productHashes =
      data['productHashes'] as List<dynamic>?;
      final String? productHash = productHashes != null && productHashes.isNotEmpty
          ? productHashes[0].toString()
          : null;

      String expiry = 'N/A';
      String manufacturing = 'N/A';

      if (productHash != null) {
        try {
          final productQuery = await _firestore
              .collection('productQrs')
              .where('productHash', isEqualTo: productHash)
              .limit(1)
              .get();

          if (productQuery.docs.isNotEmpty) {
            final productData =
            productQuery.docs.first.data() as Map<String, dynamic>;
            expiry = productData['productDateOfExpiry'] as String? ?? 'N/A';
            manufacturing =
                productData['productDateOfManufacturing'] as String? ?? 'N/A';
          }
        } catch (e) {
          print('Error fetching product details: $e');
        }
      }

      dataList.add(ParentProductData(
        parentId: doc.id,
        quantity: quantity,
        productMRP: productMRP,
        status: status,
        productDateOfExpiry: expiry,
        productDateOfManufacturing: manufacturing,
        productName: productName,
      ));
    }

    return dataList;
  }

  Widget _buildLoadingState() {
    return Container(
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
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Loading inventory...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: EdgeInsets.all(30),
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
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
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
              'No inventory yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Scan QR codes to add items',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(ParentProductData data) {
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
                              data.productName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: MyColors.blueColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'ID: ${data.parentId.substring(0, 10)}...',
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
                    'Qty: ${data.quantity.toInt()}',
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
              value: '₹${data.productMRP.toStringAsFixed(2)}',
              color: Colors.green,
            ),
            SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.check_circle,
              label: 'Status',
              value: data.status,
              color: data.status.toLowerCase().contains('processed')
                  ? Colors.blue
                  : Colors.orange,
            ),
            SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.calendar_today,
              label: 'Manufactured',
              value: data.productDateOfManufacturing,
              color: Colors.purple,
            ),
            SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.date_range,
              label: 'Expires',
              value: data.productDateOfExpiry,
              color: Colors.red,
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