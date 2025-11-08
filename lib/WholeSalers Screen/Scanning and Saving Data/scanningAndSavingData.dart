import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hackula1/UI%20Helper/Colors/colors.dart';
import 'package:hackula1/UI%20Helper/Gradients/gradients.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

Future<bool> _simulateWarehousingProcess(BuildContext context, String productHash) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return true;
}

class WholesalerQRScannerScreen extends StatefulWidget {
  const WholesalerQRScannerScreen({super.key});

  @override
  _WholesalerQRScannerScreenState createState() => _WholesalerQRScannerScreenState();
}

class _WholesalerQRScannerScreenState extends State<WholesalerQRScannerScreen> with TickerProviderStateMixin {
  late MobileScannerController scannerController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  String? detectedCode;
  bool isFlashEnabled = false;
  bool isCameraActive = true;
  bool isCameraInitialized = false;
  bool _isDisposed = false;
  bool _isProcessing = false;

  // Status message fields
  String? _statusMessage;
  MessageType? _messageType;

  // Animation Controllers
  late AnimationController _scanLineController;
  late AnimationController _cornerController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _messageController;

  // Animations
  late Animation<double> _scanLineAnimation;
  late Animation<double> _cornerAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _messageSlideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startCamera();
      }
    });
  }

  Future<void> _startCamera() async {
    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      setState(() {
        isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    scannerController.dispose();
    _scanLineController.dispose();
    _cornerController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _scanLineController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _cornerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    _messageController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    _cornerAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _cornerController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _messageSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _messageController, curve: Curves.easeOut));
  }

  void _showMessage(String message, MessageType type) {
    if (_isDisposed) return;
    setState(() {
      _statusMessage = message;
      _messageType = type;
    });
    _messageController.forward();

    // Auto-hide non-error messages after 3 seconds
    if (type != MessageType.error) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _hideMessage();
        }
      });
    }
  }

  void _hideMessage() {
    _messageController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _statusMessage = null;
          _messageType = null;
        });
      }
    });
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!isCameraActive || _isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String productHash = barcodes.first.rawValue!;
      setState(() {
        detectedCode = productHash;
        isCameraActive = false;
        _isProcessing = true;
      });

      HapticFeedback.heavyImpact();
      _handleWarehousingScan(productHash);
    }
  }

  Future<Map<String, dynamic>> _fetchCurrentUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        // Collect required user details
        return {
          'address': userDoc.data()?['address'] ?? 'N/A',
          'manufacturer_name': userDoc.data()?['manufacturer_name'] ?? 'N/A',
          'email': userDoc.data()?['email'] ?? 'N/A',
          'phone': userDoc.data()?['phone'] ?? 'N/A',
          'role': userDoc.data()?['role'] ?? 'Manufacturer',
          'uid': userId,
        };
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
    return {};
  }

  void _handleWarehousingScan(String productHash) async {
    scannerController.stop();

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showMessage('User not logged in. Please log in.', MessageType.error);
      _resetScanner();
      return;
    }

    try {
      _showMessage('Checking product status...', MessageType.info);

      // Fetch user details for record
      final userData = await _fetchCurrentUserDetails(currentUser.uid);
      final String userRole = userData['role'] ?? 'Unknown';

      if (userData.isEmpty) {
        throw Exception("Failed to fetch user details for tracking record.");
      }

      // Check if scanned code matches Parent QR
      final parentQuerySnapshot = await _firestore
          .collection('parentQrs')
          .where('parentHash', isEqualTo: productHash)
          .limit(1)
          .get();

      if (parentQuerySnapshot.docs.isNotEmpty) {
        // Parent Hash logic
        final parentDoc = parentQuerySnapshot.docs.first;
        final List<dynamic>? productHashesDynamic = parentDoc.data()['productHashes'];
        final List<String> childHashes = productHashesDynamic?.cast<String>() ?? [];

        if (childHashes.isEmpty) {
          throw Exception("Parent QR found but contains no linked product hashes.");
        }

        await _processBatchUpdate(
          productHashes: childHashes,
          parentDocId: parentDoc.id,
          userData: userData,
          userRole: userRole,
        );
      } else {
        // Check single productQrs
        final productQuerySnapshot = await _firestore
            .collection('productQrs')
            .where('productHash', isEqualTo: productHash)
            .limit(1)
            .get();

        if (productQuerySnapshot.docs.isNotEmpty) {
          final singleHash = [productHash];
          await _processBatchUpdate(
            productHashes: singleHash,
            parentDocId: null,
            userData: userData,
            userRole: userRole,
          );
        } else {
          _showMessage('Product not found in catalog.', MessageType.error);
          await Future.delayed(const Duration(seconds: 2));
          _resetScanner();
        }
      }
    } catch (e) {
      _showMessage('Process failed: ${e.toString()}', MessageType.error);
      await Future.delayed(const Duration(seconds: 2));
      _resetScanner();
    }
  }

  Future<void> _processBatchUpdate({
    required List<String> productHashes,
    required String? parentDocId,
    required Map<String, dynamic> userData,
    required String userRole,
  }) async {
    _showMessage('Verifying wholesaler status...', MessageType.info);

    // Check for existing wholesaler records in trackRecord
    final productQrsSnapshot = await _firestore.collection('productQrs')
        .where('productHash', whereIn: productHashes)
        .get();

    for (var doc in productQrsSnapshot.docs) {
      final trackRecord = doc.data()['productTrackRecord'] as List<dynamic>? ?? [];
      final hasWarehousingRecord = trackRecord.any((record) =>
      record is Map && record.containsKey('wholesaler'));
      if (hasWarehousingRecord) {
        _showMessage('Cryptographic Rejection "Error": Immutability', MessageType.error);
        await Future.delayed(const Duration(seconds: 3));
        _resetScanner();
        return;
      }
    }

    // Simulate confirmation dialog or action
    final bool confirmed = await _simulateWarehousingProcess(context, productHashes.first);

    if (!confirmed) {
      _showMessage('Wholesaler update cancelled.', MessageType.info);
      _resetScanner();
      return;
    }

    _showMessage('Saving wholesaler details...', MessageType.info);

    // Use client-side Timestamp for nested fields
    final Timestamp clientTimestamp = Timestamp.fromDate(DateTime.now());

    final Map<String, dynamic> warehousingMap = {
      'wholesaler': {
        'timestamp': clientTimestamp,
        'address': userData['address'],
        'wholesaler_name': userData['manufacturer_name'], // Assuming manufacturer_name as wholesaler name
        'email': userData['email'],
        'phone': userData['phone'],
        'role': 'wholesaler',
        'uid': userData['uid'],
      }
    };

    const String newStatus = 'Wholesaler Details added';
    final batch = _firestore.batch();

    // Update all linked productQrs with new warehousing info
    for (var doc in productQrsSnapshot.docs) {
      final docRef = doc.reference;
      batch.update(docRef, {
        'productTrackRecord': FieldValue.arrayUnion([warehousingMap]),
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update parentQrs document if exists
    if (parentDocId != null) {
      final parentRef = _firestore.collection('parentQrs').doc(parentDocId);
      batch.update(parentRef, {
        'wholesalerUid': _auth.currentUser!.uid,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    final int count = productQrsSnapshot.docs.length + (parentDocId != null ? 1 : 0);
    _showMessage('Wholesaler details saved successfully for $count document(s)!', MessageType.success);
    await Future.delayed(const Duration(seconds: 2));
    _resetScanner();
  }

  void _resetScanner() async {
    if (!mounted) return;

    try {
      await scannerController.start();
      setState(() {
        detectedCode = null;
        isCameraActive = true;
        _isProcessing = false;
        _hideMessage();
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showMessage('Failed to resume scanner: ${e.toString()}', MessageType.error);
    }
  }

  Future<void> _toggleFlashlight() async {
    if (!isCameraInitialized) {
      _showMessage('Camera is still initializing...', MessageType.info);
      return;
    }
    try {
      await scannerController.toggleTorch();
      if (mounted) {
        setState(() {
          isFlashEnabled = !isFlashEnabled;
        });
        HapticFeedback.lightImpact();
      }
    } on PlatformException {
      _showMessage('Flashlight not available', MessageType.error);
    }
  }

  Future<void> _pickFromGallery() async {
    scannerController.stop();

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        HapticFeedback.lightImpact();
        _showMessage('Analyzing image...', MessageType.info);

        final result = await scannerController.analyzeImage(image.path);

        if (result != null && result.barcodes.isNotEmpty) {
          final code = result.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            _handleWarehousingScan(code);
          } else {
            _showMessage('QR code is empty', MessageType.error);
            _resetScanner();
          }
        } else {
          _showMessage('No QR code detected in image', MessageType.error);
          _resetScanner();
        }
      } else {
        _resetScanner();
      }
    } on PlatformException {
      _showMessage('Permission denied to access gallery', MessageType.error);
      _resetScanner();
    } catch (e) {
      _showMessage('Failed to analyze image: ${e.toString()}', MessageType.error);
      _resetScanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              if (isCameraInitialized)
                Positioned.fill(
                  child: MobileScanner(
                    controller: scannerController,
                    onDetect: _onBarcodeDetected,
                  ),
                )
              else
                _buildInitializationScreen(),
              _buildScannerOverlay(),
              _buildTopHeader(),
              _buildBottomControls(),
              _buildInstructionsPanel(),
              if (_statusMessage != null) _buildStatusMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData icon;

    switch (_messageType!) {
      case MessageType.success:
        bgColor = Colors.green.shade500;
        textColor = Colors.white;
        borderColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case MessageType.error:
        bgColor = Colors.red.shade500;
        textColor = Colors.white;
        borderColor = Colors.red.shade700;
        icon = Icons.error;
        break;
      case MessageType.info:
        bgColor = MyColors.blueColor;
        textColor = Colors.white;
        borderColor = Colors.blue.shade700;
        icon = Icons.info;
        break;
    }

    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _messageSlideAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: bgColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_messageType == MessageType.error)
                GestureDetector(
                  onTap: _hideMessage,
                  child: Icon(Icons.close, color: textColor, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitializationScreen() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    const double scanAreaSize = 280.0;
    final screenSize = MediaQuery.of(context).size;
    final left = (screenSize.width - scanAreaSize) / 2;
    final top = (screenSize.height - scanAreaSize) / 2 - 40;

    return Stack(
      children: [
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  child: Container(
                    width: scanAreaSize,
                    height: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: SizedBox(
            width: scanAreaSize,
            height: scanAreaSize,
            child: Stack(
              children: [
                if (isCameraActive && !_isProcessing)
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      return Positioned(
                        left: 20,
                        right: 20,
                        top: scanAreaSize * _scanLineAnimation.value,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                MyColors.blueColor.withOpacity(0.8),
                                MyColors.blueColor,
                                MyColors.blueColor.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
                ...List.generate(
                    4, (index) => _buildAnimatedCorner(index, scanAreaSize)),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 1.0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCorner(int index, double scanAreaSize) {
    const double cornerLength = 40.0;
    final positions = [
      {'top': 0.0, 'left': 0.0},
      {'top': 0.0, 'right': 0.0},
      {'bottom': 0.0, 'left': 0.0},
      {'bottom': 0.0, 'right': 0.0},
    ];
    final pos = positions[index];

    return AnimatedBuilder(
      animation: _cornerAnimation,
      builder: (context, child) {
        return Positioned(
          top: pos['top'],
          left: pos['left'],
          right: pos['right'],
          bottom: pos['bottom'],
          child: Transform.scale(
            scale: _cornerAnimation.value,
            child: SizedBox(
              width: cornerLength,
              height: cornerLength,
              child: CustomPaint(
                painter: CornerBracketPainter(
                  color: MyColors.blueColor,
                  strokeWidth: 4,
                  cornerLength: cornerLength,
                  cornerIndex: index,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeaderButton(
              Icons.arrow_back_ios_new,
                  () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Text(
                'Scan Product QR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _buildHeaderButton(
              isFlashEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              _toggleFlashlight,
              isActive: isFlashEnabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? Colors.amber.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: MyColors.blueColor,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 50,
      left: 30,
      right: 30,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                Icons.photo_library_rounded,
                'Gallery',
                _pickFromGallery,
              ),
              _buildMainActionButton(),
              _buildControlButton(
                Icons.refresh_rounded,
                'Reset',
                    () {
                  _resetScanner();
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _cornerAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isCameraActive && !_isProcessing
                  ? _cornerAnimation.value
                  : 1.0,
              child: GestureDetector(
                onTap: () {
                  if (isCameraActive && !_isProcessing) {
                    setState(() {
                      isCameraActive = false;
                    });
                    HapticFeedback.mediumImpact();

                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() {
                          isCameraActive = true;
                        });
                      }
                    });
                  } else if (!_isProcessing) {
                    _resetScanner();
                    HapticFeedback.lightImpact();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: isCameraActive && !_isProcessing
                        ? MyGradients.blueGradient
                        : LinearGradient(
                      colors: [
                        Colors.grey.shade600,
                        Colors.grey.shade700,
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: isCameraActive && !_isProcessing
                        ? [
                      BoxShadow(
                        color: MyColors.blueColor.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                        : [],
                  ),
                  child: _isProcessing
                      ? SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(
                    isCameraActive
                        ? Icons.qr_code_scanner_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          _isProcessing ? 'Processing...' : (isCameraActive ? 'Scanning...' : 'Start Scan'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsPanel() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.75,
      left: 50,
      right: 50,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.center_focus_strong_rounded,
                  color: MyColors.blueColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Position Product QR in the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Adding Warehousing details...',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum MessageType { success, error, info }

class CornerBracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final int cornerIndex;

  CornerBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.cornerIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    const double cornerRadiusOffset = 8;
    const double lineStartOffset = 0;

    switch (cornerIndex) {
      case 0: // Top-Left
        path.moveTo(cornerLength, lineStartOffset);
        path.lineTo(cornerRadiusOffset, lineStartOffset);
        path.arcToPoint(Offset(lineStartOffset, cornerRadiusOffset),
            radius: const Radius.circular(cornerRadiusOffset));
        path.lineTo(lineStartOffset, cornerLength);
        break;
      case 1: // Top-Right
        path.moveTo(lineStartOffset, lineStartOffset);
        path.lineTo(cornerLength - cornerRadiusOffset, lineStartOffset);
        path.arcToPoint(Offset(cornerLength, cornerRadiusOffset),
            radius: const Radius.circular(cornerRadiusOffset));
        path.lineTo(cornerLength, cornerLength);
        break;
      case 2: // Bottom-Left
        path.moveTo(lineStartOffset, lineStartOffset);
        path.lineTo(lineStartOffset, cornerLength - cornerRadiusOffset);
        path.arcToPoint(Offset(cornerRadiusOffset, cornerLength),
            radius: const Radius.circular(cornerRadiusOffset));
        path.lineTo(cornerLength, cornerLength);
        break;
      case 3: // Bottom-Right
        path.moveTo(cornerLength, lineStartOffset);
        path.lineTo(cornerLength, cornerLength - cornerRadiusOffset);
        path.arcToPoint(Offset(cornerLength - cornerRadiusOffset, cornerLength),
            radius: const Radius.circular(cornerRadiusOffset));
        path.lineTo(lineStartOffset, cornerLength);
        break;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
