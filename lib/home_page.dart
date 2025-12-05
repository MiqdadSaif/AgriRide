import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_password_auth_page.dart';
import 'profile_page.dart';
import 'nearby_vehicles_page.dart';
import 'add_vehicle_page.dart';
import 'my_vehicles_page.dart';
import 'owner_bookings_page.dart';
import 'farmer_bookings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState()
   {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async 
  {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            final Object? raw = doc.data()?['role'];
            final String? normalized = raw is String ? raw.toLowerCase() : null;
            _userRole = normalized ?? 'unknown';
            _isLoading = false;
          });
        } else {
          setState(() {
            _userRole = 'no role assigned';
            _isLoading = false;
          });
        }
      } catch (e) {
        // If role fetch fails, avoid surfacing an error label to the user UI.
        // Fall back to a neutral state and allow manual refresh.
        debugPrint('Failed to load user role: $e');
        setState(() {
          _userRole = 'no role assigned';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _userRole = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const EmailPasswordAuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'AgriRent',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadUserRole,
            tooltip: 'Refresh role',
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            icon: const Icon(Icons.account_circle, color: Colors.white),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.red),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF34D399)),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Welcome section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34D399).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF34D399),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, ${user?.displayName ?? 'User'}!',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email ?? 'No email',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),),],),),],),
                        const SizedBox(height: 20),
                      
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getRoleColor().withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getRoleColor().withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getRoleIcon(),
                                color: _getRoleColor(),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Role',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _displayRoleLabel(_userRole),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _getRoleColor(),
                                    ),
                                  ),],),],),),],),),
                  const SizedBox(height: 30),
                  
                  Text(
                    'Dashboard',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildRoleSpecificContent(),
                  ),],),),);}

  Widget _buildRoleSpecificContent() {
    switch (_userRole?.toLowerCase()) {
      case 'farmer':
        return _buildFarmerContent();
      case 'owner':
        return _buildOwnerContent();
      default:
        return _buildDefaultContent();
    }
  }

  Widget _buildFarmerContent() {
    return Column(
      children: [
        _buildActionCard(
          icon: Icons.search,
          title: 'Find Vehicles',
          subtitle: 'Browse available vehicles for rent',
          color: const Color(0xFF34D399),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NearbyVehiclesPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.book_online,
          title: 'My Bookings',
          subtitle: 'View your booking status',
          color: Colors.orange,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const FarmerBookingsPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOwnerContent() {
    return Column(
      children: [
        _buildActionCard(
          icon: Icons.add_circle,
          title: 'Add Vehicle',
          subtitle: 'List a new vehicle for rent',
          color: const Color(0xFF34D399),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AddVehiclePage(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.list,
          title: 'My Vehicles',
          subtitle: 'Manage your listed vehicles',
          color: const Color(0xFF60A5FA),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MyVehiclesPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.book_online,
          title: 'My Bookings',
          subtitle: 'View and confirm booking requests',
          color: Colors.orange,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const OwnerBookingsPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDefaultContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No role assigned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please contact support to assign a role to your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor() {
    switch (_userRole?.toLowerCase()) {
      case 'farmer':
        return const Color(0xFF34D399);
      case 'owner':
        return const Color(0xFF60A5FA);
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon() {
    switch (_userRole?.toLowerCase()) {
      case 'farmer':
        return Icons.agriculture;
      case 'owner':
        return Icons.business;
      default:
        return Icons.person;
    }
  }

  String _displayRoleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'farmer':
        return 'Farmer';
      case 'owner':
        return 'Owner';
      case 'no role assigned':
        return 'No role assigned';
      default:
        return 'Unknown';
    }
  }
}

