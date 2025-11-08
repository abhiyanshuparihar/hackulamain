import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hackula1/Customer%20Screens/Recent%20Settlements%20Pages/Recent%20Settlement%20Screen/recentSettlementScreen.dart';
import 'package:hackula1/UI%20Helper/Colors/colors.dart';
import 'package:hackula1/UI%20Helper/Gradients/gradients.dart';

extension StringCasingExtension on String {
  String capitalizeWords() =>
      split(' ').map((str) => str.isNotEmpty
          ? '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}'
          : '').join(' ');
}

// Data model representing connection info
class ConnectionDetails {
  final String accountHolderName;
  final String shopAddress;
  final DateTime createdAt;
  final bool activeConnection;
  final String storeUid;

  ConnectionDetails({
    required this.accountHolderName,
    required this.shopAddress,
    required this.createdAt,
    required this.activeConnection,
    required this.storeUid,
  });
}

class SettlementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId =>
      _auth.currentUser?.uid ?? 'MOCK_USER_ID_NO_AUTH';

  Future<List<QueryDocumentSnapshot>> _fetchSettlementRooms() async {
    if (_auth.currentUser == null) {
      print("Warning: User not logged in. Querying using mock ID: $currentUserId");
    }
    try {
      final querySnapshot = await _db.collection('settlementRooms')
          .where('userUid', isEqualTo: currentUserId)
          .get();
      return querySnapshot.docs;
    } catch (e) {
      print("Error fetching settlement rooms: $e");
      rethrow;
    }
  }

  Future<DocumentSnapshot> _fetchStoreDetails(String storeUid) {
    return _db.collection('stores').doc(storeUid).get();
  }

  Future<List<ConnectionDetails>> fetchAllConnections() async {
    final roomDocs = await _fetchSettlementRooms();
    final List<Future<ConnectionDetails>> futures = [];
    for (final roomDoc in roomDocs) {
      final roomData = roomDoc.data() as Map<String, dynamic>;
      final storeUid = roomData['storeUid'] as String;
      final activeConnection = roomData['activeConnection'] as bool;

      final future = _fetchStoreDetails(storeUid).then((storeDoc) {
        if (storeDoc.exists && storeDoc.data() != null) {
          final storeData = storeDoc.data() as Map<String, dynamic>;
          final Timestamp? timestamp = storeData['createdAt'] as Timestamp?;
          final DateTime createdAt = timestamp?.toDate() ?? DateTime(2000, 1, 1);

          return ConnectionDetails(
            accountHolderName: storeData['accountHolderName'] as String,
            shopAddress: storeData['shopAddress'] as String,
            createdAt: createdAt,
            activeConnection: activeConnection,
            storeUid: storeUid,
          );
        }
        print("Store details not found for UID: $storeUid referenced by ${roomDoc.id}");
        throw Exception("Store details not found for UID: $storeUid");
      });
      futures.add(future);
    }
    return await Future.wait(futures);
  }
}

// MAIN RecentShops page with search and capitalization
class AllRooms extends StatefulWidget {
  const AllRooms({super.key});

  @override
  State<AllRooms> createState() => _AllRoomsState();
}

class _AllRoomsState extends State<AllRooms> with TickerProviderStateMixin {
  final SettlementService _settlementService = SettlementService();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late Future<List<ConnectionDetails>> _allConnectionsFuture;
  List<ConnectionDetails> _allConnections = [];
  List<ConnectionDetails> _filteredConnections = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _allConnectionsFuture = _loadConnections();
    _initAnimations();
    _searchController.addListener(_onSearchChanged);
  }

  Future<List<ConnectionDetails>> _loadConnections() async {
    final conns = await _settlementService.fetchAllConnections();
    setState(() {
      _allConnections = conns;
      _filteredConnections = conns;
    });
    return conns;
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConnections = List.from(_allConnections);
      } else {
        _filteredConnections = _allConnections.where((conn) =>
        conn.accountHolderName.toLowerCase().contains(query) ||
            conn.shopAddress.toLowerCase().contains(query)
        ).toList();
      }
    });
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Shops',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: MyColors.blueColor,
                  ),
                ),
                Text(
                  'Your connected Shops',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: MyGradients.blueGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store,
              color:Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MyColors.blueColor.withOpacity(0.12),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search Connected Shops...',
          hintStyle: TextStyle(
            color: MyColors.blueColor,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: MyColors.blueColor),
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 0),
        ),
        style: TextStyle(
            fontSize: 16, color: MyColors.blueColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildContent() {
    return FutureBuilder<List<ConnectionDetails>>(
      future: _allConnectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (_filteredConnections.isEmpty) {
          return _buildEmptyState();
        }
        return _buildConnectionsList(_filteredConnections);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: MyGradients.blueGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MyColors.blueColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading your shops...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade100, Colors.red.shade50],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Please check your network connection and try again',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _allConnectionsFuture = _loadConnections();
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: MyColors.blueColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade50,
                      Colors.indigo.shade50,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.store_outlined,
                  size: 48,
                  color: MyColors.blueColor,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No Shops Connected',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Connect with shops to see them here',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionsList(List<ConnectionDetails> connections) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: ConnectionCard(
                  connection: connections[index],
                  index: index,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ConnectionCard extends StatefulWidget {
  final ConnectionDetails connection;
  final int index;

  const ConnectionCard({
    super.key,
    required this.connection,
    required this.index,
  });

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _getStatusChip(bool isActive){
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        gradient: isActive
            ? MyGradients.blueGradient
            : MyGradients.blueGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: Colors.white,
          ),
          SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _scaleController.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
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
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _getStatusChip(widget.connection.activeConnection),
                    IconButton(
                      onPressed: (){
                        Navigator.push(context,MaterialPageRoute(builder: (context)=>SettlementDetailsPage(roomId: "${widget.connection.storeUid}_${FirebaseAuth.instance.currentUser!.uid}")));
                      },
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: MyColors.blueColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  widget.connection.accountHolderName.capitalizeWords(),
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: MyColors.blueColor,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade50,
                            Colors.indigo.shade50,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        size: 16,
                        color: MyColors.blueColor,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.connection.shopAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade50,
                            Colors.indigo.shade50,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: MyColors.blueColor,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Registered on: ${_formatDate(widget.connection.createdAt)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
