import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hackula/Common%20Screens/Help%20and%20Support/helpandSupport.dart';
import 'package:hackula/Common%20Screens/Login%20Screen/loginScreen.dart';
import 'package:hackula/Customer%20Screens/My%20Profile%20Section/myProfileSection.dart';
import 'package:hackula/Customer%20Screens/Pay%20Contact%20Screen/payContactScreen.dart';
import 'package:hackula/Customer%20Screens/Pay%20UPI%20ID%20Screen/payUpiIdScree.dart';
import 'package:hackula/Customer%20Screens/Qr%20Code%20Scanning%20Page/qrCodeScanningPage.dart';
import 'package:hackula/Customer%20Screens/Recent%20Credits%20Screen/recentCredits.dart';
import 'package:hackula/Customer%20Screens/Recent%20Settlements%20Pages/Room%20Showing%20Page/showingallRooms.dart';
import 'package:hackula/Customer%20Screens/Recent%20Shops/recentShops.dart';
import 'package:hackula/UI%20Helper/Colors/colors.dart';
import 'package:hackula/UI%20Helper/Gradients/gradients.dart';
import 'dart:math' as math;


class CustomerHomeScreen extends StatefulWidget {
  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> with TickerProviderStateMixin {
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

  String _firstName = 'User';
  bool _isDrawerOpen = false;
  bool _isLoadingCredits = true; // New loading state
  FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _recentCredits = [];

  final List<Map<String, dynamic>> _sidebarItems = [
    {
      'title': 'Recent Credits',
      'icon': Icons.credit_card,
      'gradient': [Color(0xFF667eea), Color(0xFF764ba2)],
    },
    {
      'title': 'Recent Settlements',
      'icon': Icons.receipt_long,
      'gradient': [Color(0xFF4facfe), Color(0xFF00f2fe)],
    },
    {
      'title': 'My Profile',
      'icon': Icons.person,
      'gradient': [Color(0xFFf093fb), Color(0xFFf5576c)],
    },
    {
      'title': 'Help & Support',
      'icon': Icons.help,
      'gradient': [Color(0xFF30cfd0), Color(0xFF91a7ff)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchFirstName();
    _initAnimations();
    _fetchRecentCredits();
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

  Future<void> _fetchFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _firstName = (userDoc.data() as Map<String, dynamic>?)?['firstName'] ?? 'User';
          });
        }
      } catch (e) {
        print("Error fetching user data: $e");
      }
    }
  }

  Future<void> _fetchRecentCredits() async {
    setState(() {
      _isLoadingCredits = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingCredits = false;
      });
      return;
    }

    try {
      // Limit to 4 credits only
      QuerySnapshot creditSnapshot = await FirebaseFirestore.instance
          .collection('credits')
          .where('fromUid', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(4)
          .get();

      List<Map<String, dynamic>> creditsList = [];

      for (QueryDocumentSnapshot creditDoc in creditSnapshot.docs) {
        final creditData = creditDoc.data() as Map<String, dynamic>;
        String roomId = creditData['roomId'];
        String amount = creditData['amount'].toString();
        Timestamp timestamp = creditData['timestamp'];

        // Find settlement room
        DocumentSnapshot settlementRoomDoc = await FirebaseFirestore.instance
            .collection('settlementRooms')
            .doc(roomId)
            .get();

        if (!settlementRoomDoc.exists) continue;

        String storeUid = (settlementRoomDoc.data() as Map<String, dynamic>)['storeUid'];

        // Find store
        DocumentSnapshot storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(storeUid)
            .get();

        String accountHolderName = 'Unknown Store';
        if (storeDoc.exists) {
          accountHolderName = (storeDoc.data() as Map<String, dynamic>)['accountHolderName'] ?? 'Unknown Store';
        }

        creditsList.add({
          'name': accountHolderName,
          'icon': Icons.shopping_cart,
          'amount': '₹$amount',
          'time': _formatTimestamp(timestamp),
          'color': Colors.green,
        });
      }
      setState(() {
        _recentCredits = creditsList;
        _isLoadingCredits = false;
      });
    } catch (e) {
      print("Error fetching recent credits: $e");
      setState(() {
        _isLoadingCredits = false;
      });
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

  String _formatTimestamp(Timestamp timestamp) {
    DateTime time = timestamp.toDate();
    DateTime now = DateTime.now();
    Duration diff = now.difference(time);

    if (diff.inDays == 0) {
      return "Today";
    } else if (diff.inDays == 1) {
      return "Yesterday";
    } else if (diff.inDays == 2) {
      return "Day before Yesterday";
    } else if (diff.inDays < 7) {
      return "${diff.inDays} days ago";
    } else if (diff.inDays < 30) {
      return "${diff.inDays} days ago";
    } else {
      return "${time.day}/${time.month}/${time.year}";
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

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      print('User signed out successfully.');
    } catch (e) {
      print('Error signing out: $e');
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
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 25),
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
                      child: _buildRecentShops(),
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          // Sidebar overlay
          if (_isDrawerOpen)
            GestureDetector(
              onTap: _toggleDrawer,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),

          // Modern Sidebar
          SlideTransition(
            position: _drawerSlideAnimation,
            child: _buildModernSidebar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _toggleDrawer,
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
                    Icons.menu,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
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
                      _firstName,
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
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.indigo.shade50,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: MyColors.blueColor,
                  size: 24,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSidebar() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(5, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Sidebar header
            Container(
              padding: EdgeInsets.only(top: 34,left: 24,bottom: 24,right: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: MyGradients.blueGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MyColors.blueColor,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'Assets/Images/bakaya-logo.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 10,),
                  Padding(
                    padding: const EdgeInsets.only(left: 18.0),
                    child: Text("BAKAYA",style: TextStyle(
                        color: MyColors.blueColor,
                        fontSize: 27
                    ),),
                  ),
                  SizedBox(width: 100),
                  GestureDetector(
                    onTap: _toggleDrawer,
                    child: Icon(
                      Icons.close,
                      color: MyColors.blueColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 20),
                itemCount: _sidebarItems.length,
                itemBuilder: (context, index) {
                  final item = _sidebarItems[index];
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: (){
                          HapticFeedback.lightImpact();
                          _toggleDrawer();
                          if(item['title'] =='Recent Credits'){
                            Navigator.push(context,MaterialPageRoute(builder: (context)=>AllRecentCreditsPage()));
                          }
                          else if(item['title'] == 'My Profile'){
                            Navigator.push(context,MaterialPageRoute(builder: (context)=>MyProfilePage(userId:FirebaseAuth.instance.currentUser!.uid)));
                          }
                          else if(item['title'] == 'Help & Support'){
                            Navigator.push(context, MaterialPageRoute(builder: (context)=>HelpSupportPage()));
                          }
                          else if(item['title'] == 'Recent Settlements'){
                            Navigator.push(context, MaterialPageRoute(builder: (context)=>AllRooms()));
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: MyGradients.blueGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item['icon'],
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  item['title'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
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
                    ),
                  );
                },
              ),
            ),
            // Logout button
            Container(
              margin: EdgeInsets.only(top: 16,bottom: 46,left: 26,right: 26),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _signOut();
                    Navigator.pushReplacement(context,MaterialPageRoute(builder: (context)=>LoginScreen()));
                  },
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: MyGradients.blueGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentShops() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Credits',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: MyColors.blueColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 19),
        Container(
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
          child: _isLoadingCredits
              ? Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading recent credits...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
              : (_recentCredits.isEmpty)
              ? Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.credit_card_off,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No recent credits available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
              : Column(
            children: _recentCredits.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> shop = entry.value;
              bool isLast = index == _recentCredits.length - 1;
              return Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isLast ? Colors.transparent : Colors.grey.shade100,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: MyGradients.blueGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        shop['icon'],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            shop['time'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      shop['amount'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: MyColors.blueColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(double.infinity, 180),
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
                                  'BAKAYA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Secure • Fast • Reliable',
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
                                      Icons.account_balance_wallet,
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
                            _build3DFeatureIcon(Icons.security, 'Secure'),
                            SizedBox(width: 24),
                            _build3DFeatureIcon(Icons.flash_on, 'Fast'),
                            SizedBox(width: 24),
                            _build3DFeatureIcon(Icons.verified, 'Trusted'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFloatingPaymentIcon(Icons.credit_card, Offset(-20, 200), Colors.orange),
          _buildFloatingPaymentIcon(Icons.phone_android, Offset(300, 50), Colors.green),
          _buildFloatingPaymentIcon(Icons.qr_code, Offset(320, 220), Colors.blue),
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                Icons.qr_code_scanner,
                'Scan QR',
                MyGradients.blueGradient,
              ),
              _buildActionButton(
                Icons.phone,
                'Pay Contact',
                MyGradients.blueGradient,
              ),
              _buildActionButton(
                Icons.account_balance_wallet,
                'UPI Pay',
                MyGradients.blueGradient,
              ),
              _buildActionButton(
                Icons.shopping_cart,
                'Recent Shops',
                MyGradients.blueGradient,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, LinearGradient gradient) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if(label == "Pay Contact"){
          Navigator.push(context,MaterialPageRoute(builder: (context)=>PaymentPageWithPhone()));
        }
        if(label == "UPI Pay"){
          Navigator.push(context,MaterialPageRoute(builder: (context)=>PaymentPage()));
        }
        if(label == "Recent Shops"){
          Navigator.push(context,MaterialPageRoute(builder: (context)=>RecentShops()));
        }
        else if(label == 'Scan QR'){
          Navigator.push(context,MaterialPageRoute(builder: (context)=>FreshQRScannerScreen()));
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
                  color: gradient.colors.first.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
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
}
// Custom painter for 3D card effect
class _3DCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path();
    // Draw 3D grid lines
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
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.8, size.height * 0.2);
    path.moveTo(size.width, 0);
    path.lineTo(size.width * 0.2, size.height * 0.2);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}