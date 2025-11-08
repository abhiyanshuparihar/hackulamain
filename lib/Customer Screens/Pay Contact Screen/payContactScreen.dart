import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hackula/Customer%20Screens/Home%20Screen%20Customer/homeScreenCustomer.dart';
import 'package:hackula/UI%20Helper/Gradients/gradients.dart';
import 'dart:ui';
import 'dart:async';

class PaymentPageWithPhone extends StatefulWidget {
  const PaymentPageWithPhone({Key? key}) : super(key: key);

  @override
  State<PaymentPageWithPhone> createState() => _PaymentPageWithPhoneState();
}

class _PaymentPageWithPhoneState extends State<PaymentPageWithPhone>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _successController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _pulseAnimation;

  bool isProcessing = false;
  bool isVerifyingPhone = false;
  bool showSuccessScreen = false;
  bool showFailureScreen = false;
  String? accountHolderName;
  String? savedAccountHolderName; // Store for success screen
  bool phoneVerified = false;
  String? storeUid;
  String? failureMessage;
  Timer? _autoNavigationTimer;
  String? myPaymentDoneAccountName;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _phoneController.addListener(_onPhoneNumberChanged);
  }

  void _initializeAnimations(){
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.8, 1.0, curve: Curves.elasticInOut),
      ),
    );

    // Start initial animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _successController.dispose();
    _autoNavigationTimer?.cancel();
    _phoneController.removeListener(_onPhoneNumberChanged);
    _phoneController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// -------------------------
  /// Success & Failure Animation Logic
  /// -------------------------
  void _showSuccessAnimation() {
    setState(() {
      showSuccessScreen = true;
      showFailureScreen = false;
      savedAccountHolderName = accountHolderName;
    });

    _successController.forward();

    // Start auto navigation timer (10 seconds)
    _autoNavigationTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }

  void _showFailureAnimation(String errorMessage) {
    setState(() {
      showFailureScreen = true;
      showSuccessScreen = false;
      failureMessage = errorMessage;
    });
    _successController.forward();
    // Auto navigation timer for failure (8 seconds)
    _autoNavigationTimer = Timer(const Duration(seconds: 8), () {
      if (mounted){
        _navigateBack();
      }
    });
  }

  void _navigateToHome() {
    _autoNavigationTimer?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => CustomerHomeScreen()),
          (route) => false,
    );
  }

  void _navigateBack() {
    _autoNavigationTimer?.cancel();
    setState(() {
      showFailureScreen = false;
      showSuccessScreen = false;
      failureMessage = null;
      isProcessing = false;
    });
    _successController.reset();
  }

  /// -------------------------
  /// Phone Number Verification Logic
  /// -------------------------
  void _onPhoneNumberChanged() {
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.length < 10) {
      setState(() {
        accountHolderName = null;
        phoneVerified = false;
        storeUid = null;
      });
      return;
    }

    if (phoneNumber.length == 10 && RegExp(r'^[0-9]+$').hasMatch(phoneNumber)) {
      _verifyPhoneNumber(phoneNumber);
    }
  }

  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    if (isVerifyingPhone) return;

    setState(() {
      isVerifyingPhone = true;
      accountHolderName = null;
      phoneVerified = false;
    });

    try {
      final storeSnapshot = await FirebaseFirestore.instance
          .collection("stores")
          .where("phoneNumber", isEqualTo: phoneNumber)
          .limit(1)
          .get();
      if (storeSnapshot.docs.isNotEmpty) {
        final storeDoc = storeSnapshot.docs.first;
        final rawAccountHolderName = storeDoc.data()['accountHolderName'] as String?;

        if (rawAccountHolderName != null){
          final formattedName = _formatAccountHolderName(rawAccountHolderName);
          setState(() {
            myPaymentDoneAccountName = rawAccountHolderName;
            accountHolderName = formattedName;
            phoneVerified = true;
            storeUid = storeDoc.id;
            isVerifyingPhone = false;
          });

          HapticFeedback.lightImpact();
        } else {
          throw Exception("Account holder name not found");
        }
      } else {
        setState(() {
          accountHolderName = null;
          phoneVerified = false;
          storeUid = null;
          isVerifyingPhone = false;
        });
      }
    } catch (e) {
      setState(() {
        accountHolderName = null;
        phoneVerified = false;
        storeUid = null;
        isVerifyingPhone = false;
      });
    }
  }

  String _formatAccountHolderName(String rawName) {
    return rawName.toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// -------------------------
  /// Process Payment Logic
  /// -------------------------
  Future<void> _processPayment() async {
    if (_phoneController.text.isEmpty || _amountController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      _showFailureAnimation("Please enter a valid phone number and amount.");
      return;
    }

    if (!phoneVerified || storeUid == null) {
      HapticFeedback.heavyImpact();
      _showFailureAnimation("Please enter a valid phone number that exists in our system.");
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      HapticFeedback.heavyImpact();
      _showFailureAnimation("Please enter a valid amount greater than zero.");
      return;
    }

    setState(() {
      isProcessing = true;
    });
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();

      // Firestore operations
      final storeDoc = await FirebaseFirestore.instance.collection('stores').doc(storeUid).get();
      if (!storeDoc.exists) {
        throw Exception("Store not found with the verified ID.");
      }

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
        });
        // Clear form
        _phoneController.clear();
        _amountController.clear();
        _noteController.clear();
        setState(() {
          phoneVerified = false;
          storeUid = null;
        });

        // Show success animation
        _showSuccessAnimation();
      }
    } catch (e) {
      setState(() {
        isProcessing = false;
      });

      String errorMessage;
      if (e.toString().contains('network') ||
          e.toString().contains('internet') ||
          e.toString().contains('connection')) {
        errorMessage = "No internet connection. Please check your network and try again.";
      } else if (e.toString().contains('permission')) {
        errorMessage = "Permission denied. Please check your account permissions.";
      } else if (e.toString().contains('timeout')) {
        errorMessage = "Connection timeout. Please try again later.";
      } else {
        errorMessage = "Payment failed. Please try again.";
      }

      _showFailureAnimation(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showSuccessScreen) {
      return _buildSuccessScreen();
    } else if (showFailureScreen) {
      return _buildFailureScreen();
    } else {
      return _buildPaymentScreen();
    }
  }

  /// -------------------------
  /// Main Payment Screen
  /// -------------------------
  Widget _buildPaymentScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SlideTransition(
                position: _slideAnimation,
                child: _buildHeaderSection(),
              ),
              const SizedBox(height: 30),
              SlideTransition(
                position: _slideAnimation,
                child: _buildPaymentForm(),
              ),
              const SizedBox(height: 40),
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

  /// -------------------------
  /// Success Screen (PhonePe Style)
  /// -------------------------
  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration:BoxDecoration(
          gradient: MyGradients.blueGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with animation
              Expanded(
                flex: 2,
                child: FadeTransition(
                  opacity: _successAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated success icon
                      ScaleTransition(
                        scale: _pulseAnimation,
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
                            builder: (context, child) {
                              return CustomPaint(
                                painter: PhonePeCheckmarkPainter(_checkAnimation.value),
                                child: const SizedBox(width: 120, height: 120),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Success text
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(_successAnimation),
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
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(_successAnimation),
                        child: Text(
                          'Credit sent to $myPaymentDoneAccountName',
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

              // Bottom section
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(_successAnimation),
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Done button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: MyGradients.blueGradient,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00C853).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _navigateToHome,
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
                          // Timer
                          _buildSuccessTimer(),
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

  /// -------------------------
  /// Failure Screen
  /// -------------------------
  Widget _buildFailureScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE53935),
              Color(0xFFD32F2F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with animation
              Expanded(
                flex: 2,
                child: FadeTransition(
                  opacity: _successAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated failure icon
                      ScaleTransition(
                        scale: _pulseAnimation,
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
                            builder: (context, child) {
                              return CustomPaint(
                                painter: PhonePeCrossPainter(_checkAnimation.value),
                                child: const SizedBox(width: 120, height: 120),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Failure text
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(_successAnimation),
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
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(_successAnimation),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            failureMessage ?? 'An error occurred while processing your credit',
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

              // Bottom section
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(_successAnimation),
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Try again button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
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
                                onTap: _navigateBack,
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
                          // Timer
                          _buildFailureTimer(),
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

  Widget _buildSuccessTimer() {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => 19 - i).take(20),
      builder: (context, snapshot) {
        final timeLeft = snapshot.data ?? 20;
        return Text(
          'Returning to home in ${timeLeft + 1}s',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  Widget _buildFailureTimer() {
    return StreamBuilder<int>(
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
    );
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
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0XFF261863),
            size: 20,
          ),
        ),
      ),
      title: const Text(
        'Pay Contact',
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
            color: const Color(0XFF261863).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.phone_android,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay with Phone',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Enter phone number to send payment',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0XFF261863),
            ),
          ),
          const SizedBox(height: 24),
          _buildPhoneNumberField(),
          if (isVerifyingPhone) _buildVerifyingIndicator(),
          if (accountHolderName != null) _buildAccountHolderDisplay(),
          const SizedBox(height: 20),
          _buildAmountField(),
          const SizedBox(height: 20),
          _buildNoteField(),
        ],
      ),
    );
  }

  Widget _buildPhoneNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: phoneVerified
                  ? Colors.green
                  : (_phoneController.text.length == 10 && !phoneVerified && !isVerifyingPhone)
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              if (phoneVerified)
                BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              hintText: "Enter 10-digit phone number",
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.phone,
                  color: phoneVerified ? Colors.green : const Color(0XFF261863),
                  size: 24,
                ),
              ),
              suffixIcon: _buildPhoneFieldSuffix(),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              counterText: "",
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildPhoneFieldSuffix() {
    if (isVerifyingPhone) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0XFF261863)),
          ),
        ),
      );
    }

    if (phoneVerified) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 24,
        ),
      );
    }

    if (_phoneController.text.length == 10 && !phoneVerified) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          Icons.error_outline,
          color: Colors.red.shade400,
          size: 24,
        ),
      );
    }

    return null;
  }

  Widget _buildVerifyingIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0XFF261863)),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Verifying phone number...',
            style: TextStyle(
              color: Color(0XFF261863),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountHolderDisplay() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.green.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_user,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Verified',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  accountHolderName!,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24,
          ),
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
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: "Enter amount",
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: const Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFF261863),
                  ),
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(
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
        const SizedBox(height: 8),
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
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.note_alt_outlined,
                  color: Color(0XFF261863),
                  size: 24,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        gradient: const LinearGradient(
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
            color: const Color(0XFF261863).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isProcessing ? null : _processPayment,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: isProcessing
                ? const Row(
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
                const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  accountHolderName != null
                      ? 'Pay $accountHolderName'
                      : 'Send Credit',
                  style: const TextStyle(
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
    );
  }
}

/// -------------------------
/// Custom Painters for PhonePe Style Animations
/// -------------------------
class PhonePeCheckmarkPainter extends CustomPainter {
  final double animationValue;

  PhonePeCheckmarkPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00C853)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final checkmarkSize = size.width * 0.25;

    // Create checkmark path
    final path = Path();
    path.moveTo(center.dx - checkmarkSize / 2, center.dy);
    path.lineTo(center.dx - checkmarkSize / 8, center.dy + checkmarkSize / 3);
    path.lineTo(center.dx + checkmarkSize / 2, center.dy - checkmarkSize / 2);

    // Animate the checkmark
    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final pathMetric = pathMetrics.first;
      final totalLength = pathMetric.length;
      final currentLength = totalLength * animationValue;
      final animatedPath = pathMetric.extractPath(0, currentLength);
      canvas.drawPath(animatedPath, paint);
    }
  }

  @override
  bool shouldRepaint(PhonePeCheckmarkPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class PhonePeCrossPainter extends CustomPainter {
  final double animationValue;

  PhonePeCrossPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final crossSize = size.width * 0.2;

    // First line (top-left to bottom-right)
    final path1 = Path();
    path1.moveTo(center.dx - crossSize, center.dy - crossSize);
    path1.lineTo(center.dx + crossSize, center.dy + crossSize);

    // Second line (top-right to bottom-left)
    final path2 = Path();
    path2.moveTo(center.dx + crossSize, center.dy - crossSize);
    path2.lineTo(center.dx - crossSize, center.dy + crossSize);

    // Animate both lines
    final pathMetrics1 = path1.computeMetrics().toList();
    final pathMetrics2 = path2.computeMetrics().toList();

    if (pathMetrics1.isNotEmpty) {
      final pathMetric1 = pathMetrics1.first;
      final totalLength1 = pathMetric1.length;
      final currentLength1 = totalLength1 * (animationValue * 2).clamp(0.0, 1.0);
      final animatedPath1 = pathMetric1.extractPath(0, currentLength1);
      canvas.drawPath(animatedPath1, paint);
    }

    if (pathMetrics2.isNotEmpty && animationValue > 0.5) {
      final pathMetric2 = pathMetrics2.first;
      final totalLength2 = pathMetric2.length;
      final currentLength2 = totalLength2 * ((animationValue - 0.5) * 2);
      final animatedPath2 = pathMetric2.extractPath(0, currentLength2);
      canvas.drawPath(animatedPath2, paint);
    }
  }

  @override
  bool shouldRepaint(PhonePeCrossPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}