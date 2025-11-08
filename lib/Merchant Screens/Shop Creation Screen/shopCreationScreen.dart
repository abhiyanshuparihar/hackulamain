import 'package:flutter/material.dart';
import 'package:hackula/Merchant%20Screens/Home%20Screen%20Merchant/homeScreenMerchant.dart';
import 'package:hackula/UI%20Helper/Colors/colors.dart';
import 'package:hackula/UI%20Helper/Gradients/gradients.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:qr_code_tools/qr_code_tools.dart';

class ShopCreationPage extends StatefulWidget {
  @override
  _ShopCreationPageState createState() => _ShopCreationPageState();
}

class _ShopCreationPageState extends State<ShopCreationPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Form Controllers
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _shopAddressController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();

  File? _selectedQRImage;
  String? _extractedUpiUri;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool _isQRVerified = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
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
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _phoneNumberController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _pickQRImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedQRImage = File(image.path);
          _isAnalyzing = true;
          _extractedUpiUri = null;
          _isQRVerified = false;
        });
        await _analyzeQRCode(File(image.path));
        setState(() {
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _extractedUpiUri = null;
        _isQRVerified = false;
      });
      _showErrorDialog(
        'Image Selection Error',
        'Failed to select image. Please try again.',
      );
    }
  }

  Future<void> _analyzeQRCode(File imageFile) async {
    try {
      setState(() {
        _isAnalyzing = true;
      });

      String? qrCodeContent = await QrCodeToolsPlugin.decodeFrom(imageFile.path);

      if (qrCodeContent != null && qrCodeContent.isNotEmpty) {
        if (qrCodeContent.startsWith('upi://pay')) {
          _extractedUpiUri = qrCodeContent;
          _parseAndFillUpiDetails(qrCodeContent);
          setState(() {
            _isQRVerified = true;
          });

          _showSuccessSnackbar('UPI QR code analyzed successfully!');
        } else {
          _extractedUpiUri = null;
          _isQRVerified = false;
          throw Exception('QR code does not contain valid UPI payment information');
        }
      } else {
        _extractedUpiUri = null;
        _isQRVerified = false;
        throw Exception('Could not read QR code from the image');
      }
    } catch (e) {
      _extractedUpiUri = null;
      _isQRVerified = false;
      _showErrorDialog(
        'QR Analysis Failed',
        'Could not analyze QR code. Please ensure the QR is clear and contains valid UPI information.',
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _parseAndFillUpiDetails(String upiUri) {
    try {
      final uri = Uri.parse(upiUri);
      final queryParams = uri.queryParameters;

      if (queryParams['pa'] != null) {
        _upiIdController.text = queryParams['pa']!;
      }

      if (queryParams['pn'] != null) {
        _shopNameController.text = Uri.decodeComponent(queryParams['pn']!);
      }

      _showSuccessSnackbar('UPI details extracted and filled automatically!');
    } catch (e) {
      print('Error parsing UPI URI: $e');
    }
  }

  String? _extractUpiIdFromUri(String upiUri) {
    try {
      final uri = Uri.parse(upiUri);
      return uri.queryParameters['pa'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveShopToFirebase() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      String upiUri;
      String finalUpiId;

      if (_selectedQRImage != null && _extractedUpiUri != null) {
        upiUri = _extractedUpiUri!;
        finalUpiId = _extractUpiIdFromUri(upiUri) ?? _upiIdController.text.trim();
      } else {
        upiUri = _createUpiUri();
        finalUpiId = _upiIdController.text.trim();
      }

      Map<String, dynamic> shopData = {
        'ownerId': currentUser.uid,
        'accountHolderName': _shopNameController.text.trim(),
        'shopAddress': _shopAddressController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'upiId': finalUpiId,
        'upiUri': upiUri,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('stores').add(shopData);
    } catch (e) {
      throw Exception('Failed to save shop data: $e');
    }
  }

  String _createUpiUri() {
    String shopName = Uri.encodeComponent(_shopNameController.text.trim());
    String upiId = _upiIdController.text.trim();
    return 'upi://pay?pa=$upiId&pn=$shopName&mc=1234';
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF8F9FA),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: MyColors.blueColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => MerchantHomeScreen()),
                            (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF8F9FA),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: MyColors.blueColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF8F9FA),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: MyColors.blueColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: MyGradients.blueGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: MyColors.blueColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create My Shop',
          style: TextStyle(
            color: MyColors.blueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildHeader(),
                ),
                SizedBox(height: 30),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildWelcomeSection(),
                ),
                SizedBox(height: 30),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildQRSection(),
                ),
                SizedBox(height: 30),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildFormSection(),
                ),
                SizedBox(height: 30),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildCompleteButton(),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Setup Shop',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: MyColors.blueColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Step 2 of 2 - Shop Information.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: MyColors.pinkColor,
          ),
        ),
        SizedBox(height: 16),
        _buildProgressIndicator(),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: MyGradients.blueGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: MyGradients.blueGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildIllustrationIcon(Icons.store, Colors.white),
            _buildIllustrationIcon(Icons.location_on, Colors.white),
            _buildIllustrationIcon(Icons.payment, Colors.white)
          ],
        ),
      ),
    );
  }

  Widget _buildIllustrationIcon(IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildFormSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _shopNameController,
            label: 'Shop Holder name',
            hint: 'Enter your shop holder name',
            icon: Icons.store,
            readOnly: _isQRVerified,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter shop name';
              }
              return null;
            },
          ),
          SizedBox(height: 20),
          _buildTextField(
            controller: _shopAddressController,
            label: 'Shop Address',
            hint: 'Enter complete shop address',
            icon: Icons.location_on,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter shop address';
              }
              return null;
            },
          ),
          SizedBox(height: 20),
          _buildTextField(
            controller: _phoneNumberController,
            label: 'Phone Number',
            hint: 'Enter 10-digit phone number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter phone number';
              }
              if (value.length != 10) {
                return 'Please enter a valid 10-digit phone number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MyColors.blueColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            validator: validator,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: MyColors.pinkColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: MyColors.blueColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shop Details',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: MyColors.blueColor,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Upload QR Code Image',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MyColors.blueColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Note: Shop Name and UPI ID will be auto-detected from the QR code.',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade500,
          ),
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: _pickQRImage,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedQRImage != null
                    ? MyColors.blueColor
                    : Colors.grey.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _selectedQRImage != null
                ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _selectedQRImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                if (_isAnalyzing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Analyzing QR Code...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_extractedUpiUri != null && !_isAnalyzing)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 50,
                  color: MyColors.pinkColor,
                ),
                SizedBox(height: 12),
                Text(
                  'Tap to select QR code image',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'QR will be analyzed automatically',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        _buildTextField(
          controller: _upiIdController,
          label: 'UPI ID',
          hint: 'e.g., yourname@upi',
          icon: Icons.payments,
          readOnly: _isQRVerified,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please upload a valid UPI QR code or enter UPI ID';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid UPI ID';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCompleteButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: MyGradients.blueGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: MyColors.blueColor.withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleComplete,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        )
            : Text(
          'Complete Setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _handleComplete() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _saveShopToFirebase();
        setState(() {
          _isLoading = false;
        });
        _showSuccessDialog(
          'Shop Created Successfully!',
          'Your shop has been created successfully. Welcome to the platform!',
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        print(e);
        _showErrorDialog(
          'Shop Creation Failed',
          'Failed to create shop. Please check your connection and try again.',
        );
      }
    } else {
      _showWarningDialog(
        'Incomplete Information',
        'Please fill all fields correctly before proceeding.',
      );
    }
  }
}