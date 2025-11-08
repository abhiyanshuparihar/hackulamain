import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hackula1/Manufacturer%20Screens/Product%20Form%20Page/productFormPage.dart';
import 'package:hackula1/UI%20Helper/Colors/colors.dart';
import 'package:hackula1/UI%20Helper/Gradients/gradients.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gal/gal.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ProductQrGeneratorPage extends StatefulWidget {
  const ProductQrGeneratorPage({super.key});

  @override
  State<ProductQrGeneratorPage> createState() => _ProductQrGeneratorPageState();
}

class _ProductQrGeneratorPageState extends State<ProductQrGeneratorPage>
    with TickerProviderStateMixin {
  final TextEditingController _customCountController = TextEditingController();

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // State for the generation process
  String? _parentHash;
  List<String> _productHashes = [];
  bool _isLoading = false;
  bool _isGenerated = false;
  String? _errorMessage;

  // State for the input form
  String _selectedCount = '1';
  int _numberOfQrs = 1;
  final List<String> _dropdownOptions = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'Custom'
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _customCountController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _generateRandomHash({int length = 50}) {
    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _storeProductHashInFirestore(String hash) async {
    await FirebaseFirestore.instance.collection('productQrs').add({
      'productHash': hash,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _storeParentHashInFirestore(
      String parentHash, List<String> productHashes, int quantity) async {
    await FirebaseFirestore.instance.collection('parentQrs').add({
      'parentHash': parentHash,
      'productHashes': productHashes,
      'quantity': quantity,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _initializeQrProcess() async {
    setState(() {
      _errorMessage = null;
    });

    int count = int.tryParse(_selectedCount) ?? 0;
    if (_selectedCount == 'Custom') {
      count = int.tryParse(_customCountController.text) ?? 0;
    }
    if (count <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid number of QRs (greater than 0)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _numberOfQrs = count;
      _productHashes.clear();
      _parentHash = null;
      _errorMessage = null;
    });

    try {
      final List<String> generatedProductHashes = [];
      for (int i = 0; i < count; i++) {
        final productHash = _generateRandomHash();
        generatedProductHashes.add(productHash);
        await _storeProductHashInFirestore(productHash);
      }

      String? parentHash;
      if (count > 1) {
        parentHash = _generateRandomHash();
        await _storeParentHashInFirestore(
            parentHash, generatedProductHashes, count);
      }

      setState(() {
        _productHashes = generatedProductHashes;
        _parentHash = parentHash;
        _isLoading = false;
        _isGenerated = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isGenerated = false;
        _errorMessage = 'Failed to generate QR codes: ${e.toString()}';
      });
    }
  }

  Future<Uint8List?> _generateQrCodeBytes(String data, String label,
      {double qrCodeSize = 150.0}) async {
    final double textHeight = 30.0;
    final double padding = 20.0;
    final double totalImageSize = qrCodeSize + textHeight + (padding * 2);

    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Rect backgroundRect =
    Rect.fromLTWH(0, 0, totalImageSize, totalImageSize);
    canvas.drawRect(backgroundRect, Paint()..color = Colors.white);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: '$label\nHash: ${data.substring(0, 10)}...',
        style: const TextStyle(
            color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
        minWidth: totalImageSize - (padding * 2),
        maxWidth: totalImageSize - (padding * 2));

    textPainter.paint(
      canvas,
      Offset((totalImageSize - textPainter.width) / 2, padding),
    );

    final Offset qrOffset = Offset(
      (totalImageSize - qrCodeSize) / 2,
      padding + textHeight + 10,
    );

    final Size qrAreaSize = Size(qrCodeSize, qrCodeSize);

    canvas.save();
    canvas.translate(qrOffset.dx, qrOffset.dy);
    painter.paint(canvas, qrAreaSize);
    canvas.restore();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(
        totalImageSize.toInt(), totalImageSize.toInt());
    final ByteData? byteData =
    await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  void _saveQrCode() async {
    if (!_isGenerated) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!(await Gal.requestAccess())) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Permission to save to gallery was denied';
        });
        return;
      }

      final List<Map<String, String>> hashesToSave = [];

      if (_numberOfQrs > 1 && _parentHash != null) {
        hashesToSave.add(
            {'hash': _parentHash!, 'prefix': 'box', 'displayLabel': 'Box QR'});
      }

      for (int i = 0; i < _productHashes.length; i++) {
        hashesToSave.add({
          'hash': _productHashes[i],
          'prefix': 'product_${i + 1}',
          'displayLabel': 'Product QR ${i + 1}'
        });
      }

      int savedCount = 0;
      for (var item in hashesToSave) {
        final hash = item['hash']!;
        final prefix = item['prefix']!;
        final displayLabel = item['displayLabel']!;

        final Uint8List? imageBytes =
        await _generateQrCodeBytes(hash, displayLabel, qrCodeSize: 150.0);

        if (imageBytes != null) {
          await Gal.putImageBytes(
            imageBytes,
            album: 'Product QR Codes',
            name: "${prefix}_qr_${hash.substring(0, 8)}",
          );
          savedCount++;
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } on GalException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save QR Code: ${e.type.message}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: MyColors.blueColor, size: 20),
            ),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
          ),
          title: Text(
            'QR Generator',
            style: TextStyle(
              color: MyColors.blueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: SlideTransition(
                position: _slideAnimation,
                child: _isLoading
                    ? _buildLoadingState()
                    : _isGenerated
                    ? _buildDisplaySection()
                    : _buildInputForm(),
              ),
            ),
          ),
        ),
      ),
    );
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: EdgeInsets.all(30),
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
              child: Icon(Icons.qr_code_2, color: Colors.white, size: 60),
            ),
          ),
          SizedBox(height: 30),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Generating QR Codes...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MyColors.blueColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we create your codes',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: MyGradients.blueGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: MyColors.blueColor.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 60),
              SizedBox(height: 16),
              Text(
                'Generate QR Codes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Create unique product QR codes',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 30),
        if (_errorMessage != null) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
        ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Number of Products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MyColors.blueColor,
                ),
              ),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedCount,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _dropdownOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCount = newValue!;
                      _errorMessage = null;
                    });
                  },
                ),
              ),
              if (_selectedCount == 'Custom') ...[
                SizedBox(height: 20),
                Text(
                  'Enter Custom Number',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MyColors.blueColor,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _customCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g., 50',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: MyColors.blueColor),
                    ),
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _errorMessage = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 30),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _initializeQrProcess();
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: MyGradients.blueGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: MyColors.blueColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Generate QR Codes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplaySection() {
    final String displayHash = _numberOfQrs > 1
        ? (_parentHash ?? 'Error generating Parent Hash')
        : (_productHashes.isNotEmpty
        ? _productHashes.first
        : 'Error generating Product Hash');

    final String displayType =
    _numberOfQrs > 1 ? 'Parent QR Code' : 'Product QR Code';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade50,
                  Colors.red.shade100.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
        ],

        // Success Header Card with Animation
        Container(
          padding: EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: MyGradients.blueGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: MyColors.blueColor.withOpacity(0.4),
                blurRadius: 25,
                offset: Offset(0, 12),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: MyColors.blueColor,
                    size: 40,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'QR Codes Generated!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_numberOfQrs QR code${_numberOfQrs > 1 ? 's' : ''} created successfully',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // QR Code Display Card with Enhanced Design
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with Type Badge
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
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
                        _numberOfQrs > 1 ? Icons.inventory_2 : Icons.qr_code_2,
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
                            displayType,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: MyColors.blueColor,
                            ),
                          ),
                          Text(
                            _numberOfQrs > 1
                                ? 'Contains $_numberOfQrs products'
                                : 'Individual product code',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: MyColors.blueColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: MyColors.blueColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Hash Display
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Unique Hash Code',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MyColors.blueColor.withOpacity(0.05),
                            MyColors.blueColor.withOpacity(0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MyColors.blueColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayHash,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: MyColors.blueColor,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: displayHash));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hash copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: MyColors.blueColor,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: MyColors.blueColor,
                            ),
                            padding: EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // QR Code with Modern Frame
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: MyColors.blueColor.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MyColors.blueColor.withOpacity(0.1),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Corner Decorations
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Top-left corner
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: MyColors.blueColor,
                                    width: 3,
                                  ),
                                  left: BorderSide(
                                    color: MyColors.blueColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Top-right corner
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: MyColors.blueColor,
                                    width: 3,
                                  ),
                                  right: BorderSide(
                                    color: MyColors.blueColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Bottom-left corner
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: MyColors.blueColor,
                                    width: 3,
                                  ),
                                  left: BorderSide(
                                    color: MyColors.blueColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Bottom-right corner
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: MyColors.blueColor,
                                    width: 3,
                                  ),
                                  right: BorderSide(
                                    color: MyColors.blueColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // QR Code
                          Padding(
                            padding: EdgeInsets.all(15),
                            child: QrImageView(
                              data: displayHash,
                              version: QrVersions.auto,
                              size: 250.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Scan to verify product',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Action Buttons with Enhanced Design
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductFormPage(productHash: displayHash),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MyColors.blueColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: MyColors.blueColor.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MyColors.blueColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit_document,
                          color: MyColors.blueColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Fill Details',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MyColors.blueColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _saveQrCode();
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: MyGradients.blueGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: MyColors.blueColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.download_rounded, color: Colors.white, size: 22),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download All QR Codes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _numberOfQrs > 1
                          ? 'Save ${_numberOfQrs + 1} QR codes'
                          : 'Save to gallery',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}