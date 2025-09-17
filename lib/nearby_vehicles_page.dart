import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('vehicles').get();

      final List<_Vehicle> loaded = snapshot.docs
          .map((doc) => _Vehicle.fromDoc(doc))
          .where((v) => v != null)
          .cast<_Vehicle>()
          .toList();

      setState(() {
        _vehicles = loaded;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load vehicles: $e';
      });
    } }

  List<_VehicleWithDistance> _vehiclesSortedByDistance() {
    if (_currentPosition == null) return <_VehicleWithDistance>[];
    final double userLat = _currentPosition!.latitude;
    final double userLng = _currentPosition!.longitude;

    final List<_VehicleWithDistance> withDistance = _vehicles
        .map((v) => _VehicleWithDistance(
              vehicle: v,
              distanceKm: _haversineDistanceKm(
                userLat,
                userLng,
                v.latitude,
                v.longitude,
              ), ))
        .toList();
    withDistance.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
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
              ),), ], ),),);  }

  Widget _buildListView() {
    final List<_VehicleWithDistance> vehicles = _vehiclesSortedByDistance();
    if (vehicles.isEmpty) {
      return const Center(
        child: Text(
          'No vehicles found nearby.',
          style: TextStyle(color: Colors.white70),
        ),);}
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vehicles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final _VehicleWithDistance item = vehicles[index];
        final _Vehicle v = item.vehicle;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.agriculture, color: Color(0xFF34D399)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.category,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.place, size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          '${item.distanceKm.toStringAsFixed(2)} km away',
                          style: const TextStyle(color: Colors.white70),
                        ),],), ], ), ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${v.hourlyRate}/hr',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
               fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View', style: TextStyle(color: Colors.white70)),
                  ),],),],),); }, );}}

class _Vehicle {
  final String id;
  final String name;
  final String category;
  final int hourlyRate;
  final double latitude;
  final double longitude;

  const _Vehicle({
    required this.id,
    required this.name,
    required this.category,
    required this.hourlyRate,
    required this.latitude,
    required this.longitude,
  });

  static _Vehicle? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final Map<String, dynamic>? data = doc.data();
      if (data == null) return null;
      final Map<String, dynamic>? location =
          (data['location'] as Map<String, dynamic>?);
      final double? lat = (location?['latitude']) is num
          ? (location?['latitude'] as num).toDouble()
          : null;
      final double? lng = (location?['longitude']) is num
          ? (location?['longitude'] as num).toDouble()
          : null;
      if (lat == null || lng == null) return null;
      return _Vehicle(
        id: doc.id,
        name: (data['name'] ?? 'Vehicle') as String,
        category: (data['category'] ?? 'General') as String,
        hourlyRate: ((data['hourlyRate'] ?? 0) as num).toInt(),
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
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
  });}


