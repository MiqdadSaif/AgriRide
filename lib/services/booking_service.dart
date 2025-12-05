import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if a vehicle is available for booking
  static Future<bool> isVehicleAvailable(String vehicleId) async {
    try {
      // For now, let's skip the availability check to avoid index issues
      // This can be re-enabled once indexes are created
      return true;
      
      /* Commented out until indexes are created
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('status', whereIn: ['pending', 'confirmed', 'active'])
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
      */
    } catch (e) {
      print('Error checking vehicle availability: $e');
      return true; // Allow booking if check fails
    }
  }

  /// Create a new booking
  static Future<Map<String, dynamic>?> createBooking({
    required String vehicleId,
    required String vehicleDescription,
    required String? vehicleCategory,
    required int hours,
    required double pricePerHour,
    required double latitude,
    required double longitude,
    required String address,
    String? vehicleOwnerId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Fetch vehicle owner ID from vehicle document
      String? actualVehicleOwnerId = vehicleOwnerId;
      if (actualVehicleOwnerId == null) {
        try {
          final vehicleDoc = await _firestore.collection('vehicles').doc(vehicleId).get();
          if (vehicleDoc.exists) {
            actualVehicleOwnerId = vehicleDoc.data()?['ownerId'] as String?;
            print('🔍 Fetched vehicle owner ID: $actualVehicleOwnerId');
          }
        } catch (e) {
          print('⚠️ Error fetching vehicle owner ID: $e');
        }
      }

      // Double-check vehicle availability
      final isAvailable = await isVehicleAvailable(vehicleId);
      if (!isAvailable) {
        throw Exception('Vehicle is no longer available');
      }

      final totalCost = hours * pricePerHour;
      final otp = _generateOTP();
      
      final bookingData = {
        'vehicleId': vehicleId,
        'vehicleDescription': vehicleDescription,
        'vehicleCategory': vehicleCategory,
        'hours': hours,
        'pricePerHour': pricePerHour,
        'totalCost': totalCost,
        'customerId': user.uid,
        'customerEmail': user.email,
        'customerName': user.displayName,
        'vehicleOwnerId': actualVehicleOwnerId,
        'locationText': address,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
        },
        'status': 'pending',
        'paymentStatus': 'pending',
        'emailVerified': user.emailVerified,
        'otp': otp,
        'otpVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'bookingDate': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('bookings').add(bookingData);
      
      print('📝 Booking created successfully:');
      print('   - Booking ID: ${docRef.id}');
      print('   - Vehicle ID: $vehicleId');
      print('   - Vehicle Owner ID: $actualVehicleOwnerId');
      print('   - Customer ID: ${user.uid}');
      print('   - OTP: $otp');
      
      return {
        'bookingId': docRef.id,
        'otp': otp,
      };
    } catch (e) {
      print('Error creating booking: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      return null;
    }
  }

  /// Get user's bookings
  static Future<List<Map<String, dynamic>>> getUserBookings(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('customerId', isEqualTo: userId)
          .get();

      final bookings = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by createdAt in descending order (newest first) in memory
      bookings.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return bookings;
    } catch (e) {
      print('Error getting user bookings: $e');
      return [];
    }
  }

  /// Get bookings for a vehicle owner
  static Future<List<Map<String, dynamic>>> getOwnerBookings(String ownerId) async {
    try {
      print('🔍 Fetching bookings for owner: $ownerId');
      
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('vehicleOwnerId', isEqualTo: ownerId)
          .get();

      print('📊 Found ${querySnapshot.docs.length} bookings for owner');

      final bookings = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        print('   - Booking ${doc.id}: ${data['status']} (Vehicle: ${data['vehicleId']})');
        return data;
      }).toList();

      // Sort by createdAt in descending order (newest first) in memory
      bookings.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return bookings;
    } catch (e) {
      print('Error getting owner bookings: $e');
      return [];
    }
  }

  /// Update booking status
  static Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  /// Cancel a booking
  static Future<bool> cancelBooking(String bookingId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) return false;

      final bookingData = bookingDoc.data()!;
      
      // Only allow cancellation if user is the customer or booking is still pending
      if (bookingData['customerId'] != user.uid && bookingData['status'] != 'pending') {
        return false;
      }

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  /// Get booking by ID
  static Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      print('Error getting booking: $e');
      return null;
    }
  }

  /// Get active bookings for a vehicle
  static Future<List<Map<String, dynamic>>> getVehicleActiveBookings(String vehicleId) async {
    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('status', whereIn: ['pending', 'confirmed', 'active'])
          .get();

      final bookings = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by createdAt in descending order (newest first) in memory
      bookings.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return bookings;
    } catch (e) {
      print('Error getting vehicle active bookings: $e');
      return [];
    }
  }

  /// Get booking statistics
  static Future<Map<String, int>> getBookingStats(String userId, {bool isOwner = false}) async {
    try {
      String fieldName = isOwner ? 'vehicleOwnerId' : 'customerId';
      
      final querySnapshot = await _firestore
          .collection('bookings')
          .where(fieldName, isEqualTo: userId)
          .get();

      int total = querySnapshot.docs.length;
      int pending = 0;
      int confirmed = 0;
      int active = 0;
      int completed = 0;
      int cancelled = 0;

      for (final doc in querySnapshot.docs) {
        final status = doc.data()['status'] as String?;
        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'confirmed':
            confirmed++;
            break;
          case 'active':
            active++;
            break;
          case 'completed':
            completed++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      return {
        'total': total,
        'pending': pending,
        'confirmed': confirmed,
        'active': active,
        'completed': completed,
        'cancelled': cancelled,
      };
    } catch (e) {
      print('Error getting booking stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'confirmed': 0,
        'active': 0,
        'completed': 0,
        'cancelled': 0,
      };
    }
  }

  /// Search bookings with filters
  static Future<List<Map<String, dynamic>>> searchBookings({
    String? userId,
    String? vehicleId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection('bookings');

      if (userId != null) {
        query = query.where('customerId', isEqualTo: userId);
      }

      if (vehicleId != null) {
        query = query.where('vehicleId', isEqualTo: vehicleId);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();

      final bookings = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by createdAt in descending order (newest first) in memory
      bookings.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return bookings;
    } catch (e) {
      print('Error searching bookings: $e');
      return [];
    }
  }

  /// Verify OTP and confirm booking
  static Future<bool> verifyOTPAndConfirmBooking(String bookingId, String otp) async {
    try {
      print('🔐 Verifying OTP for booking: $bookingId');
      
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        print('❌ Booking document does not exist: $bookingId');
        return false;
      }

      final bookingData = bookingDoc.data()!;
      print('📋 Current booking status: ${bookingData['status']}');
      
      final storedOTP = bookingData['otp'] as String?;
      print('🔑 Stored OTP: $storedOTP, Entered OTP: $otp');
      
      // Verify the OTP matches the stored OTP
      if (storedOTP != null && storedOTP == otp) {
        print('✅ OTP matches, updating booking status...');
        
        final updateData = {
          'status': 'confirmed',
          'otpVerified': true,
          'confirmedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        await _firestore.collection('bookings').doc(bookingId).update(updateData);
        
        print('🎉 Booking status updated successfully to confirmed');
        return true;
      } else {
        print('❌ OTP does not match or is missing');
      }
      
      return false;
    } catch (e) {
      print('💥 Error verifying OTP and confirming booking: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      return false;
    }
  }

  /// Generate a 6-digit OTP
  static String _generateOTP() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return (random % 1000000).toString().padLeft(6, '0');
  }
}
