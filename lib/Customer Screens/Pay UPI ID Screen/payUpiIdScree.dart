import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'dart:async';

class PaymentPage extends StatefulWidget {
  const PaymentPage({Key? key}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with TickerProviderStateMixin {
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // Animation controllers for form
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Animation controllers for success/failure screens
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _pulseAnimation;

  String _storeHolderName = '';
  bool _isProcessing = false;
  bool _isVerifyingUpi = false;
  Timer? _debounce;
  String? accountHolderName;

  // States for success and failure screens
  bool showSuccessScreen = false;
  bool showFailureScreen = false;
  String? failureMessage;
  String? savedStoreHolderName;

  @override
  void initState() {
    super.initState();

    // Initialize animations for form
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

    // Start form animations
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.8, 1.0, curve: Curves.elasticInOut),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _successController.dispose();

    _upiController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// -------------------------
  /// Verify UPI ID and fetch store holder name
  /// -------------------------
  void _verifyUpiId(String upiId) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      if (upiId.isEmpty) {
        setState(() {
          _storeHolderName = '';
          _isVerifyingUpi = false;
        });
        return;
      }

      setState(() {
        _isVerifyingUpi = true;
        _storeHolderName = '';
      });

      try {
        final storeSnapshot = await FirebaseFirestore.instance
            .collection("stores")
            .where("upiId", isEqualTo: upiId)
            .limit(1)
            .get();

        if (storeSnapshot.docs.isNotEmpty) {
          final storeData = storeSnapshot.docs.first.data();
          accountHolderName = storeData['accountHolderName'];
          setState(() {
            _storeHolderName = storeData['accountHolderName'] ?? 'Unknown Store';
          });
        } else {
          setState(() {
            _storeHolderName = '';
          });
        }
      } catch (e) {
        print("Error verifying UPI: $e");
        setState(() {
          _storeHolderName = '';
        });
        _showErrorDialog(
          'Verification Error',
          'Failed to verify UPI ID. Please check your internet connection and try again.',
        );
      } finally {
        setState(() {
          _isVerifyingUpi = false;
        });
      }
    });
  }

  /// -------------------------
  /// Process Payment & show animations
  /// -------------------------
  Future<void> _processPayment() async {
    if (_upiController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorDialog(
        'Invalid UPI ID',
        'Please enter a valid UPI ID to proceed with the payment.',
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      HapticFeedback.heavyImpact();
      _showErrorDialog(
        'Invalid Amount',
        'Please enter a valid amount greater than zero.',
      );
      return;
    }

    if (_storeHolderName.isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorDialog(
        'UPI Not Found',
        'The entered UPI ID does not exist in our system. Please verify and try again.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("You must be logged in to make a payment");
      }

      final upiId = _upiController.text.trim();
      final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

      final storeSnapshot = await FirebaseFirestore.instance
          .collection("stores")
          .where("upiId", isEqualTo: upiId)
          .limit(1)
          .get();

      if (storeSnapshot.docs.isEmpty) {
        throw Exception("No store found with this UPI ID");
      }

      final storeDoc = storeSnapshot.docs.first;
      final storeUid = storeDoc.id;
      final String storeAccountHolderName = storeDoc.data()['accountHolderName'] ?? "";
      final String storeOwnerId = storeDoc.data()['ownerId'] ?? '';

      if (storeOwnerId.isEmpty) {
        throw Exception("Store owner information is missing. Please contact support.");
      }

      accountHolderName = storeAccountHolderName;

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
          _isProcessing = false;
        });

        _upiController.clear();
        _amountController.clear();
        _noteController.clear();
        _storeHolderName = '';

        _showSuccessAnimation();
      }
    } on FirebaseException catch (e) {
      setState(() {
        _isProcessing = false;
      });

      String errorTitle = 'Payment Failed';
      String errorMessage;

      switch (e.code) {
        case 'permission-denied':
          errorMessage = 'You do not have permission to perform this operation.';
          break;
        case 'unavailable':
          errorMessage = 'Service is currently unavailable. Please try again later.';
          break;
        case 'deadline-exceeded':
          errorMessage = 'Request timed out. Please check your internet connection.';
          break;
        case 'not-found':
          errorMessage = 'The requested resource was not found.';
          break;
        case 'already-exists':
          errorMessage = 'A similar transaction already exists.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred while processing your payment.';
      }

      _showErrorDialog(errorTitle, errorMessage);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog(
        'Payment Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// -------------------------
  /// Show Error Dialog
  /// -------------------------
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.red.shade50, Colors.white],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade700,
                    size: 56,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade600, Colors.red.shade700],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// -------------------------
  /// Show Success Animation Screen
  /// -------------------------
  void _showSuccessAnimation() {
    setState(() {
      showSuccessScreen = true;
      showFailureScreen = false;
      savedStoreHolderName = _storeHolderName;
    });
    _successController.forward();

    // Auto close success screen after 20 seconds
    Timer(const Duration(seconds: 20), () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }

  /// -------------------------
  /// Show Failure Animation Screen
  /// -------------------------
  void _showFailureAnimation(String message) {
    setState(() {
      showFailureScreen = true;
      showSuccessScreen = false;
      failureMessage = message;
    });
    _successController.forward();

    // Auto close failure screen after 8 seconds
    Timer(const Duration(seconds: 8), () {
      if (mounted) {
        _retryPayment();
      }
    });
  }

  void _navigateToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _retryPayment() {
    setState(() {
      showFailureScreen = false;
      showSuccessScreen = false;
      failureMessage = null;
      _isProcessing = false;
    });
    _successController.reset();
  }

  /// -------------------------
  /// UI Builders: AppBar, Payment Form and Animations
  /// -------------------------
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
        'Pay with UPI',
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
              Icons.qr_code,
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
                  'Pay with UPI ID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Enter UPI ID to send payment',
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
          _buildUpiField(),
          SizedBox(height: 20),
          _buildAmountField(),
          SizedBox(height: 20),
          _buildNoteField(),
        ],
      ),
    );
  }

  Widget _buildUpiField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPI ID',
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
            border: Border.all(
              color: _storeHolderName.isNotEmpty
                  ? Colors.green
                  : _upiController.text.isNotEmpty && !_isVerifyingUpi
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              if (_storeHolderName.isNotEmpty)
                BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          child: TextField(
            controller: _upiController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: "Enter UPI ID (e.g., user@bank)",
              prefixIcon: Container(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.person,
                  color:
                  _storeHolderName.isNotEmpty ? Colors.green : Color(0XFF261863),
                  size: 24,
                ),
              ),
              suffixIcon: _buildUpiFieldSuffix(),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (value) {
              _verifyUpiId(value);
            },
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 12),
        if (_isVerifyingUpi)
          _buildVerificationIndicator()
        else if (_storeHolderName.isNotEmpty)
          _buildVerifiedNameDisplay()
        else if (_upiController.text.isNotEmpty && !_isVerifyingUpi)
            _buildErrorDisplay(),
      ],
    );
  }

  Widget _buildVerificationIndicator() {
    return Row(
      children: [
        SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0XFF261863)),
        ),
        SizedBox(width: 8),
        Text("Verifying...",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  Widget _buildVerifiedNameDisplay() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 12),
          Text(
            _toTitleCase(_storeHolderName),
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Row(
      children: [
        Icon(Icons.error, color: Colors.red.shade400, size: 16),
        SizedBox(width: 8),
        Text(
          'Invalid UPI ID',
          style: TextStyle(
            color: Colors.red.shade400,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) {
      return '';
    }
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget? _buildUpiFieldSuffix() {
    if (_storeHolderName.isNotEmpty) {
      return Container(
        padding: EdgeInsets.all(12),
        child: Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 24,
        ),
      );
    }
    return null;
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
          onTap: _isProcessing ? null : _processPayment,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            child: Center(
              child: _isProcessing
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
                    'Send Credit',
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

  /// -------------------------
  /// Success Screen Widget
  /// -------------------------
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
                          'Credit sent to ${accountHolderName ?? 'Unknown'}',
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
  /// Failure Screen Widget
  /// -------------------------
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
                          child: CustomPaint(
                            painter: PhonePeCrossPainter(_checkAnimation.value),
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
                                onTap: _retryPayment,
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

  /// -------------------------
  /// Timer Widgets for Success/Failure
  /// -------------------------
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

  /// -------------------------
  /// Override Build to show success/failure or form
  /// -------------------------
  @override
  Widget build(BuildContext context) {
    if (showSuccessScreen) {
      return _buildSuccessScreen();
    } else if (showFailureScreen) {
      return _buildFailureScreen();
    } else {
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
}

/// -------------------------
/// Custom Painters for Success & Failure Animations
/// -------------------------
class PhonePeCheckmarkPainter extends CustomPainter {
  final double animationValue;
  PhonePeCheckmarkPainter(this.animationValue);

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

    final path1 = Path();
    path1.moveTo(center.dx - crossSize, center.dy - crossSize);
    path1.lineTo(center.dx + crossSize, center.dy + crossSize);

    final path2 = Path();
    path2.moveTo(center.dx + crossSize, center.dy - crossSize);
    path2.lineTo(center.dx - crossSize, center.dy + crossSize);

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