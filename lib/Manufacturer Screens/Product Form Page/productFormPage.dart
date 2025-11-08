import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hackula1/UI%20Helper/Colors/colors.dart';
import 'package:hackula1/UI%20Helper/Gradients/gradients.dart';
import 'package:intl/intl.dart';

class ProductFormPage extends StatefulWidget {
  final String productHash;
  const ProductFormPage({required this.productHash, super.key});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrpController = TextEditingController();
  final _expiryController = TextEditingController();
  final _manufactureController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<String> _productQrDocumentIdsToUpdate = [];
  bool _isParentHash = false;
  String? _parentQrDocumentId;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  Map<String, dynamic> _manufacturerData = {};
  String _currentUserId = 'dummy-user-id';

  @override
  void initState() {
    super.initState();
    // Initialize current user ID, falling back to a dummy if needed
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
    _initAnimations();
    _initializeData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrpController.dispose();
    _expiryController.dispose();
    _manufactureController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _checkForParentHash(widget.productHash);

      // FIX 2: Safely cast the retrieved list to List<String>.
      // We expect List<String> due to the fix in _checkForParentHash, but this
      // adds another layer of safety.
      final parentHashListDynamic = result['hashes'] as List<dynamic>;
      final parentHashResult = parentHashListDynamic.cast<String>();

      _parentQrDocumentId = result['docId'] as String?;

      if (parentHashResult.isNotEmpty) {
        _isParentHash = true;
        for (String childHash in parentHashResult) {
          final docId = await _fetchProductDocumentId(childHash);
          if (docId != null) {
            _productQrDocumentIdsToUpdate.add(docId);
          }
        }
        if (_productQrDocumentIdsToUpdate.isEmpty) {
          throw Exception(
              "Parent Hash found, but none of the linked product hashes exist in 'productQrs'.");
        }
      } else {
        final docId = await _fetchProductDocumentId(widget.productHash);
        if (docId == null) {
          throw Exception("Product hash not found in productQrs collection.");
        }
        _productQrDocumentIdsToUpdate.add(docId);
      }

      _manufacturerData = await _fetchUserDetails(_currentUserId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to initialize: ${e.toString()}";
        _isLoading = false;
      });
      // Optionally show a snackbar here if you don't rely solely on the error state UI
    }
  }

  // FIX 1: Use .cast<String>() to ensure the returned list is explicitly List<String>
  Future<Map<String, dynamic>> _checkForParentHash(String hash) async {
    final query = await FirebaseFirestore.instance
        .collection('parentQrs')
        .where('parentHash', isEqualTo: hash)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final productHashes = doc.data()['productHashes'];

      if (productHashes is List) {
        return {
          'hashes': productHashes.map((e) => e.toString()).toList().cast<String>(), // <-- THE CRITICAL FIX
          'docId': doc.id,
        };
      }
    }
    // Ensure the default return type is also consistent
    return {'hashes': <String>[], 'docId': null};
  }

  Future<String?> _fetchProductDocumentId(String productHash) async {
    final query = await FirebaseFirestore.instance
        .collection('productQrs')
        .where('productHash', isEqualTo: productHash)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }
    return null;
  }

  Future<Map<String, dynamic>> _fetchUserDetails(String userId) async {
    try {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        return {
          'manufacturer_name': userDoc.data()?['manufacturer_name'] ?? 'N/A',
          'phone': userDoc.data()?['phone'] ?? 'N/A',
          'role': userDoc.data()?['role'] ?? 'Unspecified',
          'email': userDoc.data()?['email'] ?? 'N/A',
          'address': userDoc.data()?['address'] ?? 'N/A',
        };
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
    return {};
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime initialDate;
    try {
      if (controller.text.isNotEmpty) {
        initialDate = DateFormat('yyyy-MM-dd').parse(controller.text);
      } else {
        initialDate = DateTime.now();
      }
    } catch (_) {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      useRootNavigator: true, // Reliable fix for date picker display
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Please complete all required fields correctly';
      });
      return;
    }

    if (_productQrDocumentIdsToUpdate.isEmpty) {
      setState(() {
        _errorMessage = 'No valid product documents found for update';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Ensure user is logged in before using UID
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'User not authenticated. Please log in again.';
      });
      return;
    }

    final String userRole = _manufacturerData['role'] ?? 'Manufacturer';
    final Map<String, dynamic> manufacturerDetailsMap = {
      userRole: _manufacturerData,
    };

    // Data fields to update in productQrs (and will be mirrored to parentQrs)
    final Map<String, dynamic> dataToUpdate = {
      'productName': _nameController.text.trim(),
      'productMRP': double.tryParse(_mrpController.text.trim()),
      'productDateOfExpiry': _expiryController.text,
      'productDateOfManufacturing': _manufactureController.text,
      'productTrackRecord': FieldValue.arrayUnion([manufacturerDetailsMap]),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'Details Added',
      'manufactureByUid': currentUser.uid, // Add manufacturer UID
    };

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update all linked productQrs
      for (final docId in _productQrDocumentIdsToUpdate) {
        final docRef =
        FirebaseFirestore.instance.collection('productQrs').doc(docId);
        batch.update(docRef, dataToUpdate);
      }

      // 2. Update parentQrs if applicable
      if (_isParentHash && _parentQrDocumentId != null) {
        final parentRef = FirebaseFirestore.instance
            .collection('parentQrs')
            .doc(_parentQrDocumentId);

        // Fields to update in parentQrs (mirroring product details + manufacturer UID)
        final Map<String, dynamic> parentUpdateData = {
          'productName': dataToUpdate['productName'],
          'productMRP': dataToUpdate['productMRP'],
          'productDateOfExpiry': dataToUpdate['productDateOfExpiry'],
          'productDateOfManufacturing': dataToUpdate['productDateOfManufacturing'],
          'updatedAt': dataToUpdate['updatedAt'],
          'status': 'Details Added',
          'manufacturedByUid': currentUser.uid
        };

        batch.update(parentRef, parentUpdateData);
      }

      await batch.commit();

      final int count =
          _productQrDocumentIdsToUpdate.length + (_isParentHash ? 1 : 0);

      setState(() {
        _isSaving = false;
        _successMessage = 'Details saved successfully for $count document(s)!';
      });

      // Wait a moment to show success message, then pop
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Save failed: ${e.toString()}';
      });
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    String hashLabel = _isParentHash ? 'Box/Parent Hash' : 'Product Hash';
    String updateTarget = _isParentHash
        ? 'All (${_productQrDocumentIdsToUpdate.length}) Linked Products and Parent Box'
        : 'This Single Product';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: MyColors.blueColor, size: 20),
          ),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Product Details',
          style: TextStyle(
            color: MyColors.blueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _isLoading
              ? _buildLoadingState()
              : _errorMessage != null && _productQrDocumentIdsToUpdate.isEmpty
              ? _buildErrorState()
              : _buildFormContent(hashLabel, updateTarget),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: MyGradients.blueGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(MyColors.blueColor),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading Product Data...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MyColors.blueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red, size: 50),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _initializeData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: MyGradients.blueGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent(String hashLabel, String updateTarget) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_errorMessage != null &&
                _productQrDocumentIdsToUpdate.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
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
              const SizedBox(height: 20),
            ],
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: MyGradients.blueGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: MyColors.blueColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    hashLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.productHash,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.update, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Updating: $updateTarget',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MyColors.blueColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Product Name',
                    icon: Icons.inventory_2,
                    keyboardType: TextInputType.text,
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _mrpController,
                    label: 'Product MRP (₹)',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                    double.tryParse(v!) == null ? 'Valid number required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDateInputField(
                    context: context,
                    controller: _manufactureController,
                    label: 'Date of Manufacturing',
                    icon: Icons.calendar_today,
                    validator: (v) => v!.isEmpty ? 'Date is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDateInputField(
                    context: context,
                    controller: _expiryController,
                    label: 'Date of Expiry',
                    icon: Icons.date_range,
                    validator: (v) => v!.isEmpty ? 'Date is required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _isSaving
                  ? null
                  : () {
                HapticFeedback.lightImpact();
                _submitForm();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: _isSaving ? null : MyGradients.blueGradient,
                  color: _isSaving ? Colors.grey.shade300 : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isSaving
                      ? []
                      : [
                    BoxShadow(
                      color: MyColors.blueColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isSaving
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
                      'Saving...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Save Product Details',
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
        ),
      ),
    );
  }
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: MyColors.blueColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MyColors.blueColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildDateInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () async{
        // Reliable fix for date picker display (clears focus before showing dialog)
        FocusScope.of(context).unfocus();
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
        await _selectDate(context, controller);
      },
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: MyColors.blueColor),
        suffixIcon: Icon(Icons.edit_calendar, color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MyColors.blueColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}