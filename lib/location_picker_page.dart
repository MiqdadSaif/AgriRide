import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
 
class LocationPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = true;
  String? _errorMessage;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090), // New Delhi
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
        _selectedAddress = widget.initialAddress;
        setState(() {
          _isLoading = false;
        });
        return;
      }

    
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
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied.';
          _isLoading = false;
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
        _isLoading = false;
      });
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _getAddressFromCoordinates(location);
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
  
    setState(() {
      _selectedAddress = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
    });
  }


  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address': _selectedAddress,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Select Location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _selectedLocation != null ? _confirmSelection : null,
            child: const Text(
              'Confirm',
              style: TextStyle(
                color: Color(0xFF34D399),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF34D399)),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _buildMapView(),
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
              onPressed: _initializeLocation,
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

  Widget _buildMapView() {
    return Column(
      children: [
        
        Container(
          padding: const EdgeInsets.all(16),
          child: GooglePlaceAutoCompleteTextField(
            textEditingController: TextEditingController(),
            googleAPIKey: "AIzaSyCcvLR3nks52MbzwKiQEyAGEGppWfkd_Ec",
            inputDecoration: InputDecoration(
              hintText: 'Search for a location...',
              hintStyle: const TextStyle(color: Colors.grey),
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
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
            ),
            debounceTime: 600,
            countries: const ["in"], 
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: (Prediction prediction) {
              if (prediction.lat != null && prediction.lng != null) {
                final location = LatLng(double.parse(prediction.lat!), double.parse(prediction.lng!));
                setState(() {
                  _selectedLocation = location;
                  _selectedAddress = prediction.description;
                });
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(location),
                );
              }
            },
            itemClick: (Prediction prediction) {
              if (prediction.lat != null && prediction.lng != null) {
                final location = LatLng(double.parse(prediction.lat!), double.parse(prediction.lng!));
                setState(() {
                  _selectedLocation = location;
                  _selectedAddress = prediction.description;
                });
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(location),
                );
              }
            },
            itemBuilder: (context, index, Prediction prediction) {
              return Container(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prediction.description ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
            seperatedBuilder: const Divider(color: Colors.grey),
            containerHorizontalPadding: 10,
          ),
        ),
        
        
        Expanded(
          child: GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: _selectedLocation != null
                ? CameraPosition(
                    target: _selectedLocation!,
                    zoom: 15,
                  )
                : _defaultPosition,
            onTap: _onMapTap,
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedLocation!,
                      infoWindow: InfoWindow(
                        title: 'Selected Location',
                        snippet: _selectedAddress,
                      ),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            zoomControlsEnabled: false,
          ),
        ),
        
        // Selected Location Info
        if (_selectedLocation != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border(
                top: BorderSide(color: Colors.grey.shade800),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Location:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedAddress ?? 'Address not available',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
