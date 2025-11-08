import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hackula/Customer%20Screens/Online%20Settlement%20Screen/onlineSettlementScreen.dart';
import 'package:hackula/UI%20Helper/Colors/colors.dart';
import 'package:hackula/UI%20Helper/Gradients/gradients.dart';

class AllCreditsPage extends StatefulWidget {
  final String settlementRoomId;
  AllCreditsPage({required this.settlementRoomId});

  @override
  State<AllCreditsPage> createState() => _AllCreditsPageState();
}

class _AllCreditsPageState extends State<AllCreditsPage> with TickerProviderStateMixin {
  List<DocumentSnapshot> creditsDocs = [];
  List<String> selectedCreditIds = [];
  bool selectAll = false;
  double totalSelectedAmount = 0.0;
  double totalCreditsAmount = 0.0;
  double totalSettledAmount = 0.0;
  bool isLoading = true;
  bool isSelectionMode = false;
  bool isCashLoading = false;
  bool isOnlineLoading = false;

  String? storeOwnerId;
  String? upiUri;
  String? upiId;
  String? phoneNumber;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    fetchCredits();
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
    super.dispose();
  }

  Future<void> fetchCredits() async {
    final roomDoc = await FirebaseFirestore.instance
        .collection('settlementRooms')
        .doc(widget.settlementRoomId)
        .get();
    final List<dynamic> creditsIdsRaw = roomDoc['creditsIds'] ?? [];
    final List<String> creditsIds = creditsIdsRaw.cast<String>();

    // Fetch storeOwnerId from settlement room
    storeOwnerId = roomDoc['storeOwnerId'] as String?;

    // Fetch store details if storeOwnerId exists
    if (storeOwnerId != null) {
      final storeQuery = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: storeOwnerId)
          .limit(1)
          .get();

      if (storeQuery.docs.isNotEmpty) {
        final storeDoc = storeQuery.docs.first;
        upiUri = storeDoc['upiUri'] as String?;
        upiId = storeDoc['upiId'] as String?;
        phoneNumber = storeDoc['phoneNumber'] as String?;
      }
    }

    List<DocumentSnapshot> fetchedCredits = [];
    for (int i = 0; i < creditsIds.length; i += 10) {
      final end = (i + 10 < creditsIds.length) ? i + 10 : creditsIds.length;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('credits')
          .where(FieldPath.documentId, whereIn: creditsIds.sublist(i, end))
          .get();
      fetchedCredits.addAll(querySnapshot.docs);
    }

    fetchedCredits.sort((a, b) {
      final ta = a['timestamp'] as Timestamp?;
      final tb = b['timestamp'] as Timestamp?;
      final taMs = ta?.millisecondsSinceEpoch ?? 0;
      final tbMs = tb?.millisecondsSinceEpoch ?? 0;
      return tbMs - taMs;
    });

    double creditsSum = 0.0;
    double settledSum = 0.0;
    for (var doc in fetchedCredits) {
      final num amount = doc['amount'] ?? 0;
      if ((doc['isSettled'] ?? false)) {
        settledSum += amount.toDouble();
      } else {
        creditsSum += amount.toDouble();
      }
    }

    setState(() {
      creditsDocs = fetchedCredits;
      totalCreditsAmount = creditsSum;
      totalSettledAmount = settledSum;
      isLoading = false;
    });
  }

  void startSelection() {
    setState(() {
      isSelectionMode = true;
      selectedCreditIds.clear();
      selectAll = false;
      totalSelectedAmount = 0.0;
    });
  }

  void toggleSelectAll(bool? value) {
    setState(() {
      selectAll = value ?? false;
      if (selectAll) {
        selectedCreditIds = creditsDocs
            .where((doc) => !(doc['isSettled'] ?? false))
            .map((doc) => doc.id)
            .toList();
      } else {
        selectedCreditIds.clear();
      }
      _updateTotalSelectedAmount();
    });
  }

  void onCardSelect(String id, bool? value) {
    setState(() {
      if (value ?? false) {
        if (!selectedCreditIds.contains(id)) selectedCreditIds.add(id);
      } else {
        selectedCreditIds.remove(id);
      }
      selectAll = selectedCreditIds.length ==
          creditsDocs.where((doc) => !(doc['isSettled'] ?? false)).length;
      _updateTotalSelectedAmount();
    });
  }

  void _updateTotalSelectedAmount() {
    double total = 0.0;
    for (var doc in creditsDocs) {
      if (selectedCreditIds.contains(doc.id)) {
        final num amount = doc['amount'] ?? 0;
        total += amount.toDouble();
      }
    }
    totalSelectedAmount = total;
  }

  void exitSelection() {
    setState(() {
      isSelectionMode = false;
      selectedCreditIds.clear();
      selectAll = false;
      totalSelectedAmount = 0.0;
    });
  }

  void _showCustomAlert(String message, {bool isSuccess = true}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF8F9FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isSuccess ? MyGradients.blueGradient : LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: MyColors.blueColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
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

  Future<void> _createSettlementRequest(BuildContext bottomSheetContext) async {
    if (selectedCreditIds.isEmpty) return;

    setState(() {
      isCashLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final firstCreditId = selectedCreditIds.first;
      final creditDoc = await FirebaseFirestore.instance.collection('credits').doc(firstCreditId).get();

      if (!creditDoc.exists) throw Exception("Credit document not found");

      final roomId = creditDoc['roomId'] as String?;
      if (roomId == null) throw Exception("roomId not found in credit document");

      final settlementRoomDoc = await FirebaseFirestore.instance.collection('settlementRooms').doc(roomId).get();
      if (!settlementRoomDoc.exists) throw Exception("Settlement room not found");

      final storeOwnerId = settlementRoomDoc['storeOwnerId'] as String?;
      if (storeOwnerId == null) throw Exception("storeOwnerId not found");

      await FirebaseFirestore.instance.collection('settlementRequest').add({
        'creditsUids': selectedCreditIds,
        'totalAmount': totalSelectedAmount,
        'timestamp': FieldValue.serverTimestamp(),
        'requestBy': currentUser.uid,
        'requestedTo': storeOwnerId,
        'status': 'pending',
        'roomId': widget.settlementRoomId,
        'medium': 'cash',
      });

      setState(() {
        isCashLoading = false;
      });

      Navigator.pop(bottomSheetContext);
      _showCustomAlert('Cash settlement request sent successfully!');
      exitSelection();
    } catch (e) {
      setState(() {
        isCashLoading = false;
      });
      Navigator.pop(bottomSheetContext);
      _showCustomAlert('Error submitting settlement: $e', isSuccess: false);
    }
  }

  void showSettlementBottomSheet() {
    if (selectedCreditIds.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: !isCashLoading && !isOnlineLoading,
      enableDrag: !isCashLoading && !isOnlineLoading,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => !isCashLoading && !isOnlineLoading,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF8F9FA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(bottom: 24, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: MyGradients.blueGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.payment,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Select Payment Method",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: MyColors.blueColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Choose how you want to settle ₹${totalSelectedAmount.toStringAsFixed(2)}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 28),

              // --- CASH PAYMENT BUTTON (MODIFIED) ---
              GestureDetector(
                onTap: isCashLoading || isOnlineLoading
                    ? null
                    : () async {
                  HapticFeedback.mediumImpact();
                  // Set loading state to true for visual feedback and disabling
                  setState(() {
                    isCashLoading = true;
                  });
                  await _createSettlementRequest(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    // Use a different gradient when loading to indicate disabled state
                    gradient: (isCashLoading || isOnlineLoading)
                        ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
                        : MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isCashLoading || isOnlineLoading)
                            ? Colors.grey.withOpacity(0.3)
                            : MyColors.blueColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Removed the CircularProgressIndicator
                      Icon(
                          Icons.money,
                          color: Colors.white,
                          size: 24
                      ),
                      SizedBox(width: 12),
                      Text(
                        // Text changes based on loading state
                        isCashLoading ? "Processing..." : "Pay with Cash",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // --- ONLINE PAYMENT BUTTON (UNCHANGED) ---
              GestureDetector(
                onTap: isCashLoading || isOnlineLoading
                    ? null
                    : () async {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    isOnlineLoading = true;
                  });

                  setState(() {
                    isOnlineLoading = false;
                  });

                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UpiSettlementPage(
                        creditIds: selectedCreditIds,
                        totalAmount: totalSelectedAmount,
                        settlementRoomId: widget.settlementRoomId,
                        upiUri: upiUri,
                        upiId: upiId,
                        phoneNumber: phoneNumber,
                      ),
                    ),
                  ).then((_) {
                    exitSelection();
                    fetchCredits();
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: (isCashLoading || isOnlineLoading)
                        ? LinearGradient(
                      colors: [Colors.grey.shade300, Colors.grey.shade400],
                    )
                        : MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow:[
                      BoxShadow(
                        color: (isCashLoading || isOnlineLoading)
                            ? Colors.grey.withOpacity(0.3)
                            : Color(0xFF667eea).withOpacity(0.4),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isOnlineLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      else
                        Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        isOnlineLoading ? "Loading..." : "Settle Online",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 38),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Reset loading states when bottom sheet is closed
      setState(() {
        isCashLoading = false;
        isOnlineLoading = false;
      });
    });
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (isSelectionMode) {
                exitSelection();
              } else {
                Navigator.pop(context);
              }
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
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isSelectionMode ? Icons.close : Icons.arrow_back_ios_new,
                color: Colors.grey.shade600,
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
                  isSelectionMode ? 'Select Credits' : 'Credits History',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: MyColors.blueColor,
                  ),
                ),
                if (isSelectionMode && selectedCreditIds.isNotEmpty)
                  Text(
                    '₹${totalSelectedAmount.toStringAsFixed(2)} selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  )
                else
                  Text(
                    '${creditsDocs.length} transactions',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          if (!isLoading && !isSelectionMode)
            GestureDetector(
              onTap: startSelection,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Settle',
                  style: TextStyle(
                    color: MyColors.blueColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 19,
                  ),
                ),
              ),
            ),
          if (isSelectionMode) ...[
            GestureDetector(
              onTap: () => toggleSelectAll(!selectAll),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MyColors.blueColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: selectAll ? MyColors.blueColor : Colors.white,
                        border: Border.all(
                          color: MyColors.blueColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: selectAll
                          ? Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'All',
                      style: TextStyle(
                        color: MyColors.blueColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            if (selectedCreditIds.isNotEmpty)
              GestureDetector(
                onTap: showSettlementBottomSheet,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: MyColors.blueColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalsSummary() {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade100, Colors.red.shade50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.trending_up, color: Colors.red.shade600, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  "Pending",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '₹${totalCreditsAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade100, Colors.green.shade50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  "Settled",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '₹${totalSettledAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildCreditsList() {
    if (creditsDocs.isEmpty) {
      return [
        Center(
          child: Container(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade100,
                        Colors.grey.shade50,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'No Credits Available',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        )
      ];
    }

    List<Widget> widgets = [];
    String? lastDateHeader;

    for (int index = 0; index < creditsDocs.length; index++) {
      final doc = creditsDocs[index];
      final tsRaw = doc['timestamp'] as Timestamp?;
      final DateTime timestamp = tsRaw?.toDate() ?? DateTime.now();
      final String dateHeader = _formatDateHeader(timestamp);

      if (dateHeader != lastDateHeader) {
        widgets.add(
          Container(
            margin: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  dateHeader,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        );
        lastDateHeader = dateHeader;
      }

      widgets.add(_buildCreditCard(doc, timestamp, index));
    }

    return widgets;
  }

  Widget _buildCreditCard(DocumentSnapshot doc, DateTime timestamp, int index) {
    final bool isSettled = doc['isSettled'] ?? false;
    final num amount = doc['amount'] ?? 0;
    final String? note = doc['note'] as String?;
    final String id = doc.id;
    final String timeString = _formatTime(timestamp);
    final bool isSelected = selectedCreditIds.contains(id);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              onTap: isSelectionMode && !isSettled
                  ? () => onCardSelect(id, !isSelected)
                  : null,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: isSettled ? MainAxisAlignment.start : MainAxisAlignment.end,
                  children: [
                    if (isSelectionMode && !isSettled)
                      Container(
                        margin: EdgeInsets.only(right: 12),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? MyColors.blueColor : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MyColors.blueColor,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        gradient: isSettled
                            ? LinearGradient(
                          colors: [Colors.grey.shade200, Colors.grey.shade100],
                        )
                            : MyGradients.blueGradient,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: isSettled ? Radius.circular(4) : Radius.circular(16),
                          bottomRight: isSettled ? Radius.circular(16) : Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isSettled ? Colors.grey : MyColors.blueColor).withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "₹${amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSettled ? Colors.grey.shade600 : Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              if (isSettled)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Settled',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Text(
                              note,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSettled ? Colors.grey.shade600 : Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                          SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeString,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSettled ? Colors.grey.shade500 : Colors.white.withOpacity(0.8),
                                ),
                              ),
                              SizedBox(width: 4),
                              if (!isSettled)
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.8),
                                )
                              else
                                Icon(
                                  Icons.done_all,
                                  size: 12,
                                  color: Colors.green.shade600,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
              SlideTransition(
                position: _slideAnimation,
                child: _buildTotalsSummary(),
              ),
              Expanded(
                child: isLoading
                    ? Center(
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
                          'Loading credits...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ))
                    : SingleChildScrollView(
                  padding: EdgeInsets.only(top: 10, bottom: 20),
                  child: Column(
                    children: _buildCreditsList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}