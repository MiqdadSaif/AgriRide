import 'package:flutter/material.dart';
import 'booking_page.dart';

class RentNowPage extends StatefulWidget {
  final String vehicleId;
  final String vehicleDescription;
  final double pricePerHour;
  final String? vehicleCategory;

  const RentNowPage({
    super.key,
    required this.vehicleId,
    required this.vehicleDescription,
    required this.pricePerHour,
    this.vehicleCategory,
  });

  @override
  State<RentNowPage> createState() => _RentNowPageState();
}

class _RentNowPageState extends State<RentNowPage> {

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Rent Now',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              
              Container(
                padding: const EdgeInsets.all(20),
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.vehicleCategory != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(widget.vehicleCategory!),
                            color: const Color(0xFF34D399),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.vehicleCategory!,
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Color(0xFF34D399), size: 24),
                        const SizedBox(width: 6),
                        Text(
                          '₹${widget.pricePerHour.toStringAsFixed(2)} per hour',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
          
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) => BookingPage(
                          vehicleId: widget.vehicleId,
                          vehicleDescription: widget.vehicleDescription,
                          pricePerHour: widget.pricePerHour,
                          vehicleCategory: widget.vehicleCategory,
                        ),
                      ),
                    );
                    if (result == true && mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  icon: const Icon(Icons.book_online, color: Colors.black),
                  label: const Text(
                    'Book with OTP Verification',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34D399),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
            
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secure booking with phone number verification via OTP',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }}




