import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'location_picker_page.dart';

class EditVehiclePage extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicleData;

  const EditVehiclePage({
    super.key,
    required this.vehicleId,
    required this.vehicleData,
  });

  @override
  State<EditVehiclePage> createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends State<EditVehiclePage> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pricePerHourController = TextEditingController();
  final TextEditingController _pricePerDayController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverPhoneController = TextEditingController();
  final TextEditingController _locationTextController = TextEditingController();
  
  String _vehicleStatus = 'In Good Condition';
  String _vehicleCategory = 'Tractor';
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;

  File? _imageFile;
  bool _isSubmitting = false;
  String? _currentImageUrl;

  final List<String> _categoryOptions = [
    'Tractor',
    'Tiller',
    'Harvester',
    'Sprayer',
    'Cultivator',
    'Seeder',
    'Plough',
    'Other',
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _descriptionController.text = widget.vehicleData['description'] ?? '';
    _pricePerHourController.text = widget.vehicleData['pricePerHour']?.toString() ?? '';
    _pricePerDayController.text = widget.vehicleData['pricePerDay']?.toString() ?? '';
    _driverNameController.text = widget.vehicleData['driver']?['name'] ?? '';
    _driverPhoneController.text = widget.vehicleData['driver']?['phone'] ?? '';
    _locationTextController.text = widget.vehicleData['locationText'] ?? '';
    _vehicleStatus = widget.vehicleData['status'] ?? 'In Good Condition';
    _vehicleCategory = widget.vehicleData['category'] ?? 'Tractor';
    _currentImageUrl = widget.vehicleData['imageUrl'];
    
    // Initialize location data
    final location = widget.vehicleData['location'];
    if (location != null) {
      _selectedLatitude = location['latitude']?.toDouble();
      _selectedLongitude = location['longitude']?.toDouble();
    }
    _selectedAddress = widget.vehicleData['locationText'];
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          initialAddress: _selectedAddress,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
        _selectedAddress = result['address'];
        _locationTextController.text = _selectedAddress ?? 
            '${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}';
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || 
          permission == LocationPermission.denied) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _selectedLatitude = pos.latitude;
        _selectedLongitude = pos.longitude;
        _locationTextController.text = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      });
      return pos;
    } catch (_) {
      return null;
    }
  }

  String? _validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Optional field, no error if empty
    }
    
    // Remove all non-digit characters for validation
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if phone number is all zeros
    if (cleanPhone == '0000000000' || cleanPhone == '0') {
      return 'Phone number cannot be all zeros';
    }
    
    // Check if it's a valid Indian phone number (10 digits)
    if (cleanPhone.length == 10) {
      return null; // Valid phone number
    } else if (cleanPhone.length < 10) {
      return 'Phone number must be 10 digits';
    } else {
      return 'Phone number too long';
    }
  }

  Future<void> _updateVehicle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final description = _descriptionController.text.trim();
    final priceText = _pricePerHourController.text.trim();
    final pricePerDayText = _pricePerDayController.text.trim();
    final driverName = _driverNameController.text.trim();
    final driverPhone = _driverPhoneController.text.trim();
    final locationText = _locationTextController.text.trim();

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price per hour is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final double? pricePerHour = double.tryParse(priceText);
    if (pricePerHour == null || pricePerHour <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid positive price per hour.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate price per day if provided
    double? pricePerDay;
    if (pricePerDayText.isNotEmpty) {
      pricePerDay = double.tryParse(pricePerDayText);
      if (pricePerDay == null || pricePerDay <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid positive price per day.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Validate phone number if provided
    final String? phoneError = _validatePhoneNumber(driverPhone);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(phoneError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl = _currentImageUrl;

      // Upload new image if one was selected
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('vehicles')
            .child(user.uid)
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadTask = await storageRef.putFile(_imageFile!);
        imageUrl = await uploadTask.ref.getDownloadURL();
      }


      final vehicleData = <String, dynamic>{
        'description': description,
        'pricePerHour': pricePerHour,
        'pricePerDay': pricePerDay,
        'status': _vehicleStatus,
        'category': _vehicleCategory,
        'driver': {
          'name': driverName,
          'phone': driverPhone,
        },
        'location': _selectedLatitude != null && _selectedLongitude != null
            ? {
                'latitude': _selectedLatitude,
                'longitude': _selectedLongitude,
              }
            : widget.vehicleData['location'],
        'locationText': _selectedAddress ?? (locationText.isNotEmpty ? locationText : null),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only update imageUrl if a new image was uploaded
      if (imageUrl != null) {
        vehicleData['imageUrl'] = imageUrl;
      }

      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vehicleId)
          .update(vehicleData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle updated successfully.'),
          backgroundColor: Color(0xFF34D399),
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final code = e.code;
      final message = e.message ?? 'Failed to update vehicle.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update error ($code): $message'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Edit Vehicle',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : _currentImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _currentImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.image_not_supported, 
                                           color: Colors.grey, size: 40),
                                      SizedBox(height: 8),
                                      Text('Tap to select new image', 
                                           style: TextStyle(color: Colors.grey)),
                                    ],),);},),)
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.image_outlined, 
                                     color: Colors.grey, size: 40),
                                SizedBox(height: 8),
                                Text('Tap to select image', 
                                     style: TextStyle(color: Colors.grey)),
                              ],),),), ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _locationTextController,
                    label: 'Location',
                    icon: Icons.place_outlined,
                    readOnly: true,
                    onTap: _selectLocation,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34D399),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.map, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _getCurrentLocation();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Current location updated')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _pricePerHourController,
              label: 'Price per hour',
              icon: Icons.attach_money,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _pricePerDayController,
              label: 'Price per day (₹) - Optional',
              icon: Icons.calendar_today,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))
              ],
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
            const SizedBox(height: 16),
            _buildStatusDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _driverNameController,
              label: 'Driver name (optional)',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _driverPhoneController,
              label: 'Driver phone (optional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: _validatePhoneNumber,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _updateVehicle,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34D399),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Update Vehicle',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),),),],        ),),);}

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _vehicleStatus,
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          dropdownColor: Colors.grey.shade900,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          items: const [
            DropdownMenuItem(
              value: 'In Good Condition',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF34D399), size: 20),
                  SizedBox(width: 8),
                  Text('In Good Condition'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'In Repair',
              child: Row(
                children: [
                  Icon(Icons.build, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('In Repair'),
                ],
              ),
            ),
          ],
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _vehicleStatus = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _vehicleCategory,
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          dropdownColor: Colors.grey.shade900,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          items: _categoryOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(value),
                    color: const Color(0xFF34D399),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(value),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _vehicleCategory = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Tractor':
        return Icons.agriculture;
      case 'Tiller':
        return Icons.build;
      case 'Harvester':
        return Icons.grass;
      case 'Sprayer':
        return Icons.water_drop;
      case 'Cultivator':
        return Icons.terrain;
      case 'Seeder':
        return Icons.eco;
      case 'Plough':
        return Icons.construction;
      default:
        return Icons.directions_car;
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF34D399)),
        ),
        errorText: validator != null ? validator(controller.text) : null,
        errorStyle: const TextStyle(color: Colors.red),
        hintText: readOnly ? 'Tap to select location' : null,
        hintStyle: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

