import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'location_picker_page.dart';
import 'services/booking_service.dart';

class BookingPage extends StatefulWidget {
  final String vehicleId;
  final String vehicleDescription;
  final double pricePerHour;
  final String? vehicleCategory;

  const BookingPage({
    super.key,
    required this.vehicleId,
    required this.vehicleDescription,
    required this.pricePerHour,
    this.vehicleCategory,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _locationTextController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _prefillLocation();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _locationTextController.dispose();
    super.dispose();
  }

  Future<void> _prefillLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied.';
        });
        return;
      }

      final Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _selectedLatitude = pos.latitude;
        _selectedLongitude = pos.longitude;
        _locationTextController.text = 'Current Location (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
        _selectedAddress = _locationTextController.text;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
      });
    }
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerPage(),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
        _selectedAddress = result['address'];
        _locationTextController.text = result['address'] ?? '';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _locationTextController.text = 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        _selectedAddress = _locationTextController.text;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get current location: $e';
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

  
    if (_selectedLatitude == null || _selectedLongitude == null || _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location for the booking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to place a booking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email address first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final int hours = int.parse(_hoursController.text.trim());
      
      
      if (hours == 0) {
        setState(() {
          _errorMessage = 'Hours cannot be zero. Please enter a valid number of hours.';
        });
        return;
      }
      if (hours < 0) {
        setState(() {
          _errorMessage = 'Please enter a positive number of hours.';
        });
        return;
      }
      if (hours > 72) {
        setState(() {
          _errorMessage = 'Maximum 72 hours per booking.';
        });
        return;
      }

      
      final result = await BookingService.createBooking(
        vehicleId: widget.vehicleId,
        vehicleDescription: widget.vehicleDescription,
        vehicleCategory: widget.vehicleCategory,
        hours: hours,
        pricePerHour: widget.pricePerHour,
        latitude: _selectedLatitude!,
        longitude: _selectedLongitude!,
        address: _selectedAddress!,
      );

      if (result != null && mounted) {
        final bookingId = result['bookingId'];
        final otp = result['otp'];
        
        
        _showOTPDialog(otp);
      } else {
        setState(() {
          _errorMessage = 'Failed to place booking. Please check your internet connection and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to place booking: ${e.toString()}';
      });
      print('Booking error details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Book Vehicle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vehicleDescription,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.vehicleCategory != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(widget.vehicleCategory!),
                            color: const Color(0xFF34D399),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.vehicleCategory!,
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Color(0xFF34D399), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '₹${widget.pricePerHour.toStringAsFixed(2)} per hour',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF34D399)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.email,
                      color: Color(0xFF34D399),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Email verification required for booking',
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),


            
              TextFormField(
                controller: _hoursController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Number of hours',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.access_time, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.shade900,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF34D399)),
                  ),
                ),
                validator: (value) {
                  final String v = (value ?? '').trim();
                  if (v.isEmpty) return 'Please enter hours';
                  final int? n = int.tryParse(v);
                  if (n == null) return 'Enter a valid number';
                  if (n == 0) return 'Hours cannot be zero';
                  if (n < 0) return 'Enter a positive number';
                  if (n > 72) return 'Maximum 72 hours per booking';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locationTextController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Location *',
                        hintText: 'Select location for booking',
                        hintStyle: const TextStyle(color: Colors.grey),
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade900,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF34D399)),
                        ),
                      ),
                      onTap: _selectLocation,
                      validator: (value) {
                        if (_selectedLatitude == null || _selectedLongitude == null) {
                          return 'Please select a location';
                        }
                        return null;
                      },
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
                      onPressed: _getCurrentLocation,
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
              const SizedBox(height: 8),
              if (_selectedLatitude != null && _selectedLongitude != null) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Location: ${_selectedLatitude!.toStringAsFixed(5)}, ${_selectedLongitude!.toStringAsFixed(5)}',
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Please select a location for the booking',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34D399),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Place Booking',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOTPDialog(String otp) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        contentPadding: const EdgeInsets.all(16),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF34D399)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Booking Confirmation OTP',
                style: TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
              'Your booking request has been placed successfully!',
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF34D399)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Share this OTP with the vehicle owner:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    otp,
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Note: The vehicle owner will verify this OTP to confirm your booking.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
            ),
          ],
        ),
      ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); 
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34D399),
            ),
            child: const Text(
              'Got it',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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

}
