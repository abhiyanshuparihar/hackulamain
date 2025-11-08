import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hackula/UI%20Helper/Colors/colors.dart';
import 'package:hackula/UI%20Helper/Gradients/gradients.dart';
import 'package:intl/intl.dart';

class SettlementRoomsPage extends StatefulWidget {
  const SettlementRoomsPage({super.key});

  @override
  State<SettlementRoomsPage> createState() => _SettlementRoomsPageState();
}

class _SettlementRoomsPageState extends State<SettlementRoomsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<Map<String, dynamic>?> _fetchUserDetails(String userUid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userUid).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: _buildErrorState(
          icon: Icons.person_off,
          title: 'Not Logged In',
          message: 'Please log in to view settlement rooms',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('settlementRooms')
                    .where('storeOwnerId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(
                      icon: Icons.error_outline,
                      title: 'Error Loading Data',
                      message: snapshot.error.toString(),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final docs = snapshot.data!.docs;
                  return _buildRoomsList(docs);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: MyColors.blueColor,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'Customers',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: MyColors.blueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          hintText: 'Search customers...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: MyColors.blueColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade400),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
              HapticFeedback.lightImpact();
            },
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildRoomsList(List<QueryDocumentSnapshot> docs) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllUserDetails(docs),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
            ),
          );
        }

        if (userSnapshot.hasError) {
          return _buildErrorState(
            icon: Icons.error_outline,
            title: 'Error Loading Users',
            message: userSnapshot.error.toString(),
          );
        }

        final userDetails = userSnapshot.data ?? [];

        // Filter based on search query
        final filteredDocs = <int>[];
        for (int i = 0; i < docs.length; i++) {
          final userData = userDetails[i];
          final userName = "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}".trim().toLowerCase();
          final userEmail = (userData['email'] ?? '').toLowerCase();

          if (_searchQuery.isEmpty ||
              userName.contains(_searchQuery) ||
              userEmail.contains(_searchQuery)) {
            filteredDocs.add(i);
          }
        }

        if (filteredDocs.isEmpty) {
          return _buildEmptyState(isSearchResult: true);
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final docIndex = filteredDocs[index];
            final doc = docs[docIndex];
            final data = doc.data() as Map<String, dynamic>;
            final userData = userDetails[docIndex];
            return _buildRoomCard(context, doc.id, data, userData);
          },
        );
      },
    );
  }
  Future<List<Map<String, dynamic>>> _fetchAllUserDetails(List<QueryDocumentSnapshot> docs) async {
    final List<Map<String, dynamic>> userDetails = [];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userUid = data['userUid'] ?? '';
      final details = await _fetchUserDetails(userUid);
      userDetails.add(details ?? {});
    }
    return userDetails;
  }

  Widget _buildRoomCard(BuildContext context, String docId, Map<String, dynamic> data, Map<String, dynamic> userData) {
    final bool activeConnection = data['activeConnection'] ?? false;
    final Timestamp? createdAt = data['createdAt'];
    final List creditIds = data['creditsIds'] ?? [];
    final String userUid = data['userUid'] ?? '';

    String userName = "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}".trim();
    if (userName.isEmpty) userName = 'Unknown User';
    String userEmail = userData['email'] ?? '';
    String userPhone = userData['phone'] ?? '';

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreditIdsDetailPage(
                  creditIds: List<String>.from(creditIds),
                  userName: userName,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: MyGradients.blueGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person,
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
                            userName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          if (userEmail.isNotEmpty)
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: activeConnection ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: activeConnection ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            activeConnection ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: activeConnection ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade200),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.receipt_long,
                        label: 'Credits',
                        value: '${creditIds.length}',
                        color: Colors.blue,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade200,
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.calendar_today,
                        label: 'Created',
                        value: createdAt != null ? _formatDate(createdAt.toDate()) : 'N/A',
                        color: Colors.purple,
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

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  Widget _buildEmptyState({bool isSearchResult = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSearchResult ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: 24),
          Text(
            isSearchResult ? 'No Results Found' : 'No Customers Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              isSearchResult
                  ? 'Try searching with a different name or email'
                  : 'Your customers will appear here once they start transacting',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Credit Details Page
class CreditIdsDetailPage extends StatelessWidget {
  final List<String> creditIds;
  final String userName;

  const CreditIdsDetailPage({
    super.key,
    required this.creditIds,
    required this.userName,
  });

  Future<List<Map<String, dynamic>>> fetchCredits() async {
    try {
      final List<Map<String, dynamic>> credits = [];
      for (var i = 0; i < creditIds.length; i += 10) {
        final sublist = creditIds.sublist(i, (i + 10 > creditIds.length) ? creditIds.length : i + 10);
        final snap = await FirebaseFirestore.instance
            .collection('credits')
            .where(FieldPath.documentId, whereIn: sublist)
            .get();
        credits.addAll(snap.docs.map((doc) => doc.data()..['id'] = doc.id));
      }
      return credits;
    } catch (e) {
      throw Exception('Failed to load credits: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchCredits(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(
                      icon: Icons.error_outline,
                      title: 'Error Loading Credits',
                      message: snapshot.error.toString(),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
                      ),
                    );
                  }
                  final credits = snapshot.data!;
                  if (credits.isEmpty) {
                    return _buildEmptyState();
                  }
                  double pendingTotal = 0.0;
                  double settledTotal = 0.0;
                  for (final credit in credits) {
                    final amt = double.tryParse("${credit['amount'] ?? '0'}") ?? 0;
                    if (credit['isSettled'] == true) {
                      settledTotal += amt;
                    } else {
                      pendingTotal += amt;
                    }
                  }
                  return Column(
                    children: [
                      _buildSummaryCards(pendingTotal, settledTotal),
                      Expanded(
                        child: _buildCreditsList(credits),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: MyColors.blueColor,
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
                  'Credits for',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: MyColors.blueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double pendingTotal, double settledTotal) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: MyGradients.blueGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pending_actions, color: Colors.white, size: 24),
                  SizedBox(height: 12),
                  Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '₹${pendingTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: MyGradients.blueGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 24),
                  SizedBox(height: 12),
                  Text(
                    'Settled',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '₹${settledTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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

  Widget _buildCreditsList(List<Map<String, dynamic>> credits) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: credits.length,
      itemBuilder: (context, index) {
        final credit = credits[index];
        final isSettled = credit['isSettled'] ?? false;
        final amount = credit['amount'] ?? '';
        final note = (credit['note'] ?? '').toString();
        final dt = credit['timestamp'] is Timestamp
            ? DateFormat('dd MMM yyyy, hh:mm a').format(credit['timestamp'].toDate())
            : 'N/A';

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: isSettled ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSettled ? Colors.green.shade50 : MyColors.blueColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSettled ? Colors.green.shade200 : MyColors.blueColor,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSettled ? Icons.check_circle : Icons.pending,
                          color: isSettled ? Colors.green.shade700 : Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '₹$amount',
                          style: TextStyle(
                            color: isSettled ? Colors.green.shade700 : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    if (note.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        note,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        SizedBox(width: 4),
                        Text(
                          dt,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Credits Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No credit transactions available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}