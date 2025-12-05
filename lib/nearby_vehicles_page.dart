import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rent_now_page.dart';

class NearbyVehiclesPage extends StatefulWidget {
  const NearbyVehiclesPage({super.key});

  @override
  State<NearbyVehiclesPage> createState() => _NearbyVehiclesPageState();
}

class _NearbyVehiclesPageState extends State<NearbyVehiclesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Position? _currentPosition;
  String? _errorMessage;
  bool _isLoading = true;
  List<_Vehicle> _vehicles = <_Vehicle>[];

  @override
  void initState()
   {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permission denied.';
          _isLoading = false;
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission permanently denied.';
          _isLoading = false;
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      await _loadVehiclesFromFirestore();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVehiclesFromFirestore() async {
    try {
      print('Loading vehicles from Firestore...');
      
      // Try to get all documents from the vehicles collection
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('vehicles').get();

      print('Snapshot has ${snapshot.docs.length} documents');
      
      if (snapshot.docs.isEmpty) {
        print('No documents found in vehicles collection');
        setState(() {
          _vehicles = [];
        });
        return;
      }
      
      final List<_Vehicle> loaded = [];
      
      for (var doc in snapshot.docs) {
        print('Processing document ${doc.id}');
        print('Document data: ${doc.data()}');
        
        final vehicle = _Vehicle.fromDoc(doc);
        if (vehicle != null) {
          loaded.add(vehicle);
          print('Added vehicle: ${vehicle.description}');
        } else {
          print('Failed to parse vehicle from document ${doc.id}');
        }
      }

      print('Successfully loaded ${loaded.length} vehicles out of ${snapshot.docs.length} documents');
      for (var vehicle in loaded) {
        print('Vehicle: ${vehicle.description}, Price: ${vehicle.pricePerHour}');
      }

      setState(() {
        _vehicles = loaded;
      });
    } catch (e) {
      print('Error loading vehicles: $e');
      setState(() {
        _errorMessage = 'Failed to load vehicles: $e';
      });
    }
  }

  List<_VehicleWithDistance> _vehiclesSortedByDistance() {
    if (_currentPosition == null) {
      // If no location, show all vehicles without distance sorting
      return _vehicles
          .map((v) => _VehicleWithDistance(
                vehicle: v,
                distanceKm: -1, // -1 indicates no distance available
              ))
          .toList();
    }
    
    final double userLat = _currentPosition!.latitude;
    final double userLng = _currentPosition!.longitude;

    final List<_VehicleWithDistance> withDistance = _vehicles
        .where((v) => v.latitude != null && v.longitude != null)
        .map((v) => _VehicleWithDistance(
              vehicle: v,
              distanceKm: _haversineDistanceKm(
                userLat,
                userLng,
                v.latitude!,
                v.longitude!,
              ),
            ))
        .toList();
    
    // Add vehicles without location at the end
    final List<_VehicleWithDistance> withoutLocation = _vehicles
        .where((v) => v.latitude == null || v.longitude == null)
        .map((v) => _VehicleWithDistance(
              vehicle: v,
              distanceKm: -1,
            ))
        .toList();
    
    withDistance.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    withDistance.addAll(withoutLocation);
    return withDistance;
  }

  double _haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371;
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
                sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Nearby Vehicles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _initLocation,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh location',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF34D399)),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _buildListView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34D399),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    final List<_VehicleWithDistance> vehicles = _vehiclesSortedByDistance();
    print('Building list view with ${vehicles.length} vehicles');
    print('Raw vehicles list has ${_vehicles.length} items');
    
    if (vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No vehicles available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for available vehicles\nRaw count: ${_vehicles.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vehicles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final _VehicleWithDistance item = vehicles[index];
        final _Vehicle v = item.vehicle;
        return _buildVehicleCard(v, item.distanceKm);
      },
    );
  }

  Widget _buildVehicleCard(_Vehicle vehicle, double distanceKm) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade800,
              child: vehicle.imageUrl != null
                  ? Image.network(
                      vehicle.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(
                        Icons.directions_car_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          
          // Vehicle Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  vehicle.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (vehicle.ownerName == 'Vehicle Owner') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Category: ${_getCategoryFromDescription(vehicle.description)}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                
                // Price
                Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      color: Color(0xFF34D399),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₹${vehicle.pricePerHour.toStringAsFixed(2)} per hour',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Vehicle Status
                Row(
                  children: [
                    Icon(
                      vehicle.status == 'In Good Condition' 
                          ? Icons.check_circle 
                          : Icons.build,
                      color: vehicle.status == 'In Good Condition' 
                          ? const Color(0xFF34D399) 
                          : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.status,
                      style: TextStyle(
                        color: vehicle.status == 'In Good Condition' 
                            ? const Color(0xFF34D399) 
                            : Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Owner Info
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Owner: ${vehicle.ownerName}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Driver Info
                if (vehicle.driver != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.drive_eta,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Driver: ${vehicle.driver!['name'] ?? 'N/A'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.driver!['phone'] ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vehicle.locationText ?? 
                        (distanceKm >= 0 
                          ? '${distanceKm.toStringAsFixed(2)} km away'
                          : 'Location not available'),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _contactOwner(vehicle),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF34D399)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Contact Owner',
                          style: TextStyle(color: Color(0xFF34D399)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _rentVehicle(vehicle),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34D399),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Rent Now',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _contactOwner(_Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Contact Owner',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owner: ${vehicle.ownerName}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${vehicle.ownerEmail}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (vehicle.driver != null) ...[
              const SizedBox(height: 8),
              Text(
                'Driver: ${vehicle.driver!['name'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'Phone: ${vehicle.driver!['phone'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _rentVehicle(_Vehicle vehicle) async {
    final bool? placed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => RentNowPage(
          vehicleId: vehicle.id,
          vehicleDescription: vehicle.description,
          pricePerHour: vehicle.pricePerHour,
        ),
      ),
    );
    if (placed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request placed for ${vehicle.description}'),
          backgroundColor: const Color(0xFF34D399),
        ),
      );
    }
  }

  String _getCategoryFromDescription(String description) {
    if (description.toLowerCase().contains('tractor')) return 'Tractor';
    if (description.toLowerCase().contains('tiller')) return 'Tiller';
    if (description.toLowerCase().contains('harvester')) return 'Harvester';
    if (description.toLowerCase().contains('sprayer')) return 'Sprayer';
    return 'Agricultural Equipment';
  }
}

class _Vehicle {
  final String id;
  final String description;
  final double pricePerHour;
  final String? imageUrl;
  final String ownerName;
  final String ownerEmail;
  final Map<String, dynamic>? driver;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final String status;

  const _Vehicle({
    required this.id,
    required this.description,
    required this.pricePerHour,
    this.imageUrl,
    required this.ownerName,
    required this.ownerEmail,
    this.driver,
    this.locationText,
    this.latitude,
    this.longitude,
    this.status = 'In Good Condition',
  });

  static _Vehicle? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final Map<String, dynamic>? data = doc.data();
      if (data == null) {
        print('Document ${doc.id} has no data');
        return null;
      }
      
      print('Parsing vehicle data for ${doc.id}: $data');
      
      final Map<String, dynamic>? location =
          (data['location'] as Map<String, dynamic>?);
      final double? lat = (location?['latitude']) is num
          ? (location?['latitude'] as num).toDouble()
          : null;
      final double? lng = (location?['longitude']) is num
          ? (location?['longitude'] as num).toDouble()
          : null;
      
      // Handle both old and new data structures
      String description;
      double pricePerHour;
      String ownerName;
      String ownerEmail;
      String? imageUrl;
      Map<String, dynamic>? driver;
      String? locationText;
      
      // Check if it's the new structure (from add_vehicle_page.dart)
      if (data.containsKey('description')) {
        description = (data['description'] ?? 'No description') as String;
        pricePerHour = ((data['pricePerHour'] ?? 0) as num).toDouble();
        ownerName = (data['ownerName'] ?? 'Unknown Owner') as String;
        ownerEmail = (data['ownerEmail'] ?? '') as String;
        imageUrl = data['imageUrl'] as String?;
        driver = data['driver'] as Map<String, dynamic>?;
        locationText = data['locationText'] as String?;
      } else {
        // Handle old structure (from your existing data)
        description = (data['name'] ?? 'No description') as String;
        pricePerHour = ((data['hourlyRate'] ?? 0) as num).toDouble();
        ownerName = 'Vehicle Owner'; // Default for old data
        ownerEmail = 'contact@example.com'; // Default for old data
        imageUrl = null; // Old data doesn't have images
        driver = null; // Old data doesn't have driver info
        locationText = null; // Old data doesn't have location text
      }
      
      // Get vehicle status (default to 'In Good Condition' for old data)
      final String status = (data['status'] ?? 'In Good Condition') as String;
      
      final vehicle = _Vehicle(
        id: doc.id,
        description: description,
        pricePerHour: pricePerHour,
        imageUrl: imageUrl,
        ownerName: ownerName,
        ownerEmail: ownerEmail,
        driver: driver,
        locationText: locationText,
        latitude: lat,
        longitude: lng,
        status: status,
      );
      
      print('Successfully parsed vehicle: ${vehicle.description}');
      return vehicle;
    } catch (e) {
      print('Error parsing vehicle data for ${doc.id}: $e');
      return null;
    }
  }
}

class _VehicleWithDistance {
  final _Vehicle vehicle;
  final double distanceKm;

  const _VehicleWithDistance({
    required this.vehicle,
    required this.distanceKm,
  });
}


