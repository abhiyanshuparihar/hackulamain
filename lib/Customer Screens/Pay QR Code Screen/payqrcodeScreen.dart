import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:hackula1/Customer%20Screens/Home%20Screen%20Customer/homeScreenCustomer.dart';

class PayCreditWithUpiUriPage extends StatefulWidget {
  final String upiUri;
  const PayCreditWithUpiUriPage({Key? key, required this.upiUri}) : super(key: key);
  @override
  _PayCreditWithUpiUriPageState createState() => _PayCreditWithUpiUriPageState();
}

class _PayCreditWithUpiUriPageState extends State<PayCreditWithUpiUriPage> with TickerProviderStateMixin {
  String? accountHolderName;
  String? storeUid;
  bool isProcessing = false;
  bool paymentSuccess = false;
  bool paymentFailure = false;
  bool isLoading = true; // Fix: loading flag
  String? failureMessage;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _successController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    fetchStoreByUpiUri();

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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();

    _successController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> fetchStoreByUpiUri() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('upiUri', isEqualTo: widget.upiUri)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        setState(() {
          accountHolderName = data['accountHolderName'] as String? ?? '';
          storeUid = doc.id;
        });
      } else {
        setState(() {
          accountHolderName = null;
          storeUid = null;
        });
      }
    } catch (e) {
      print('Error fetching store: $e');
    } finally {
      setState(() {
        isLoading = false; // Fix: mark loading as complete
      });
    }
  }

  Future<void> _processPayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      HapticFeedback.heavyImpact();
      _showFailure("Please enter a valid amount.");
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      HapticFeedback.heavyImpact();
      _showFailure("Please enter a valid amount greater than zero.");
      return;
    }
    if (storeUid == null) {
      HapticFeedback.heavyImpact();
      _showFailure("No store found for the provided UPI URI.");
      return;
    }
    setState(() {
      isProcessing = true;
    });
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

      final storeDoc = await FirebaseFirestore.instance.collection('stores').doc(storeUid).get();
      if (!storeDoc.exists) throw Exception("Store not found");

      final storeOwnerId = storeDoc.data()?['ownerId'] as String?;
      if (storeOwnerId == null || storeOwnerId.isEmpty) {
        throw Exception("Store owner ID not found.");
      }

      final roomId = "${storeUid}_${user.uid}";
      final roomRef = FirebaseFirestore.instance.collection("settlementRooms").doc(roomId);

      final roomSnap = await roomRef.get();
      if (!roomSnap.exists) {
        await roomRef.set({
          "roomId": roomId,
          "storeUid": storeUid,
          "userUid": user.uid,
          "storeOwnerId": storeOwnerId,
          "activeConnection": true,
          "createdAt": FieldValue.serverTimestamp(),
          "creditsIds": [],
          "cashSettlementIds": [],
          "onlineSettlementIds": [],
        });
      }
      final creditRef = await FirebaseFirestore.instance.collection("credits").add({
        "roomId": roomId,
        "fromUid": user.uid,
        "amount": amount,
        "note": note,
        "isSettled": false,
        "timestamp": FieldValue.serverTimestamp(),
      });

      await roomRef.update({
        "creditsIds": FieldValue.arrayUnion([creditRef.id]),
      });

      if (mounted) {
        setState(() {
          isProcessing = false;
          paymentSuccess = true;
        });
        _amountController.clear();
        _noteController.clear();
        _successController.forward();
        Timer(const Duration(seconds: 10), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      setState(() {
        isProcessing = false;
      });

      String errorMsg = "Payment failed. Please try again.";
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('network') || errorString.contains('internet') || errorString.contains('connection')) {
        errorMsg = "No internet connection. Please check your network and try again.";
      } else if (errorString.contains('permission')) {
        errorMsg = "Permission denied. Please check your account permissions.";
      } else if (errorString.contains('timeout')) {
        errorMsg = "Connection timeout. Please try again later.";
      }
      _showFailure(errorMsg);
    }
  }

  void _showFailure(String msg) {
    setState(() {
      paymentFailure = true;
      failureMessage = msg;
    });
    _successController.forward();
    Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          paymentFailure = false;
          failureMessage = null;
        });
        _successController.reset();
      }
    });
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return '';
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: Color(0XFF261863),
            size: 20,
          ),
        ),
      ),
      title: Text(
        'Pay Credit',
        style: TextStyle(
          color: Color(0XFF261863),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0XFF131B63),
            Color(0XFF481162),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0XFF261863).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.store,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay Credit to',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _toTitleCase(accountHolderName ?? ''),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0XFF261863),
            ),
          ),
          SizedBox(height: 24),
          _buildAmountField(),
          SizedBox(height: 20),
          _buildNoteField(),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: "Enter amount",
              prefixIcon: Container(
                padding: EdgeInsets.all(12),
                child: Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFF261863),
                  ),
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0XFF261863),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Add a note for this payment...",
              prefixIcon: Container(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.note_alt_outlined,
                  color: Color(0XFF261863),
                  size: 24,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0XFF131B63),
            Color(0XFF481162),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0XFF261863).withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isProcessing ? null : _processPayment,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            child: Center(
              child: isProcessing
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Pay Credit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0XFF131B63),
              Color(0XFF481162),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: FadeTransition(
                  opacity: _successAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _successAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _checkAnimation,
                            builder: (context, child){
                              return CustomPaint(
                                painter: CheckmarkPainter(_checkAnimation.value),
                                child: const SizedBox(width: 120, height: 120),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SlideTransition(
                        position: Tween<Offset>(
                            begin: const Offset(0, 0.5), end: Offset.zero)
                            .animate(_successAnimation),
                        child: const Text(
                          'Credit Successful!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SlideTransition(
                        position: Tween<Offset>(
                            begin: const Offset(0, 0.5), end: Offset.zero)
                            .animate(_successAnimation),
                        child: Text(
                          'Credit paid to ${_toTitleCase(accountHolderName ?? '')}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0, 1), end: Offset.zero)
                        .animate(_successAnimation),
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0XFF131B63),
                                  Color(0XFF481162),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0XFF131B63).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => CustomerHomeScreen()),
                                      (Route<dynamic> route) => false,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                child: const Center(
                                  child: Text(
                                    'Done',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          StreamBuilder<int>(
                            stream: Stream.periodic(const Duration(seconds: 1), (i) => 9 - i).take(10),
                            builder: (context, snapshot) {
                              final timeLeft = snapshot.data ?? 10;
                              return Text(
                                'Returning in ${timeLeft + 1}s',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
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
      ),
    );
  }

  Widget _buildFailureScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE53935),
              Color(0xFFD32F2F),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: FadeTransition(
                  opacity: _successAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _successAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: CrossPainter(_checkAnimation.value),
                            child: const SizedBox(width: 120, height: 120),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SlideTransition(
                        position: Tween<Offset>(
                            begin: const Offset(0, 0.5), end: Offset.zero)
                            .animate(_successAnimation),
                        child: const Text(
                          'Payment Failed!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SlideTransition(
                        position: Tween<Offset>(
                            begin: const Offset(0, 0.5), end: Offset.zero)
                            .animate(_successAnimation),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            failureMessage ?? 'An error occurred while processing your payment',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0, 1), end: Offset.zero)
                        .animate(_successAnimation),
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFE53935),
                                  Color(0xFFD32F2F),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE53935).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    paymentFailure = false;
                                    failureMessage = null;
                                  });
                                  _successController.reset();
                                },
                                borderRadius: BorderRadius.circular(28),
                                child: const Center(
                                  child: Text(
                                    'Try Again',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          StreamBuilder<int>(
                            stream: Stream.periodic(const Duration(seconds: 1), (i) => 7 - i).take(8),
                            builder: (context, snapshot) {
                              final timeLeft = snapshot.data ?? 8;
                              return Text(
                                'Returning to payment form in ${timeLeft + 1}s',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fix: Show loading spinner while fetching store
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0XFF261863)),
          ),
        ),
      );
    }

    if (paymentSuccess) {
      return _buildSuccessScreen();
    } else if (paymentFailure) {
      return _buildFailureScreen();
    }
    if (accountHolderName == null || accountHolderName!.isEmpty) {
      return Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade300,
              ),
              SizedBox(height: 20),
              Text(
                "No store found",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0XFF261863),
                ),
              ),
              SizedBox(height: 8),
              Text(
                "No store found for this UPI URI.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SlideTransition(
                position: _slideAnimation,
                child: _buildHeaderSection(),
              ),
              SizedBox(height: 30),
              SlideTransition(
                position: _slideAnimation,
                child: _buildPaymentForm(),
              ),
              SizedBox(height: 40),
              ScaleTransition(
                scale: _scaleAnimation,
                child: _buildPayButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double animationValue;
  CheckmarkPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00C853)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final checkmarkSize = size.width * 0.3;

    final path = Path();
    final startPoint = Offset(center.dx - checkmarkSize * 0.6, center.dy);
    final middlePoint = Offset(center.dx - checkmarkSize * 0.1, center.dy + checkmarkSize * 0.4);
    final endPoint = Offset(center.dx + checkmarkSize * 0.6, center.dy - checkmarkSize * 0.5);

    path.moveTo(startPoint.dx, startPoint.dy);
    path.lineTo(middlePoint.dx, middlePoint.dy);
    path.lineTo(endPoint.dx, endPoint.dy);

    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      for (final pathMetric in pathMetrics) {
        final totalLength = pathMetric.length;
        final currentLength = totalLength * animationValue;
        final animatedPath = pathMetric.extractPath(0, currentLength);
        canvas.drawPath(animatedPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class CrossPainter extends CustomPainter {
  final double animationValue;
  CrossPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final crossSize = size.width * 0.2;

    final path1 = Path();
    path1.moveTo(center.dx - crossSize, center.dy - crossSize);
    path1.lineTo(center.dx + crossSize, center.dy + crossSize);

    final path2 = Path();
    path2.moveTo(center.dx + crossSize, center.dy - crossSize);
    path2.lineTo(center.dx - crossSize, center.dy + crossSize);

    final pathMetrics1 = path1.computeMetrics().toList();
    final pathMetrics2 = path2.computeMetrics().toList();

    if (pathMetrics1.isNotEmpty){
      final pathMetric1 = pathMetrics1.first;
      final totalLength1 = pathMetric1.length;
      final currentLength1 = totalLength1 * (animationValue * 2).clamp(0.0, 1.0);
      final animatedPath1 = pathMetric1.extractPath(0, currentLength1);
      canvas.drawPath(animatedPath1, paint);
    }
    if (pathMetrics2.isNotEmpty && animationValue > 0.5){
      final pathMetric2 = pathMetrics2.first;
      final totalLength2 = pathMetric2.length;
      final currentLength2 = totalLength2 * ((animationValue - 0.5) * 2);
      final animatedPath2 = pathMetric2.extractPath(0, currentLength2);
      canvas.drawPath(animatedPath2, paint);
    }
  }
  @override
  bool shouldRepaint(CrossPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
