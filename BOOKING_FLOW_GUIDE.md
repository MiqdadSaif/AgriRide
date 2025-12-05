# Complete Booking Flow with OTP Verification

## Flow Summary

### 1. Farmer Side (Booking Request)
1. **Farmer books a vehicle**
   - Navigate to "Find Vehicles" → Select vehicle → "Rent Now"
   - Fill in hours and location
   - Click "Place Booking"

2. **Farmer receives OTP**
   - System generates 6-digit OTP
   - OTP is displayed in a dialog
   - Farmer copies the OTP

3. **Farmer shares OTP**
   - Farmer contacts vehicle owner (call/SMS)
   - Provides the OTP to owner

4. **Farmer checks booking status**
   - Navigate to "My Bookings" from home page
   - See pending bookings with OTP displayed
   - Wait for owner to verify OTP

5. **Farmer receives confirmation**
   - When owner verifies OTP, booking status changes to "Confirmed"
   - Farmer sees "Booking Confirmed!" message in real-time
   - Confirmation timestamp is displayed

### 2. Owner Side (Verification & Confirmation)
1. **Owner views bookings**
   - Navigate to "My Bookings" from home page
   - See all pending bookings

2. **Owner requests OTP**
   - View pending booking details
   - Contact farmer and request the OTP

3. **Owner enters OTP**
   - Enter 6-digit OTP in the input field
   - System validates OTP automatically when all 6 digits are entered

4. **Owner verifies successfully**
   - Success message: "Booking confirmed successfully!"
   - Booking status changes to "Confirmed"
   - OTP input field disappears

5. **Owner sees confirmation**
   - Confirmed bookings show green checkmark
   - "Booking Confirmed" badge displayed

## Status Flow Diagram

```
Farmer Places Booking
        ↓
    Status: PENDING
        ↓
Farmer receives OTP
        ↓
Farmer shares OTP with Owner
        ↓
Owner enters OTP
        ↓
    [OTP Correct] → [OTP Wrong]
        ↓                ↓
Status: CONFIRMED    Error message
        ↓
Farmer sees "Booking Confirmed!"
Owner sees "Booking Confirmed!"
```

## User Interface Guide

### For Farmers
**Home Page:**
- "Find Vehicles" - Browse and book vehicles
- "My Bookings" - Check booking status

**My Bookings Page Shows:**
- Pending bookings: Orange badge with OTP displayed
- Confirmed bookings: Green badge with "Booking Confirmed!" message
- Vehicle details, hours, cost, location
- Cancel option for pending bookings

### For Vehicle Owners
**Home Page:**
- "Add Vehicle" - List new vehicles
- "My Vehicles" - Manage listed vehicles
- "My Bookings" - View and confirm bookings

**My Bookings Page Shows:**
- Pending bookings: Orange badge with OTP input field
- Confirmed bookings: Green badge with "Booking Confirmed" badge
- Customer details, hours, cost, location
- Cancel option for pending bookings

## Real-Time Updates

Both farmer and owner pages use Firestore StreamBuilder, which means:
- **No refresh needed** - Updates appear automatically
- **Instant status change** - When owner verifies OTP, farmer sees confirmation immediately
- **Live data** - All changes are synchronized in real-time

## Features

### ✅ OTP System
- 6-digit random OTP generation
- OTP stored securely in Firestore
- Single-use OTP verification
- Automatic status update on verification

### ✅ Farmer Notifications
- OTP displayed after booking
- Real-time status updates
- Clear confirmation messages
- Booking history tracking

### ✅ Owner Verification
- Simple OTP input interface
- Instant validation
- Success/error feedback
- Confirmation status display

### ✅ Status Management
- Color-coded status badges
- Status icons for quick recognition
- Timestamp tracking
- Real-time synchronization

## Firestore Fields

### Booking Document Fields
```javascript
{
  // Vehicle Info
  vehicleId: string,
  vehicleDescription: string,
  vehicleCategory: string,
  
  // Booking Details
  hours: number,
  pricePerHour: number,
  totalCost: number,
  
  // Customer Info
  customerId: string,
  customerEmail: string,
  customerName: string,
  
  // Owner Info
  vehicleOwnerId: string,
  
  // Location
  locationText: string,
  location: { latitude, longitude },
  
  // Status & OTP
  status: 'pending' | 'confirmed' | 'active' | 'completed' | 'cancelled',
  otp: string,           // 6-digit OTP
  otpVerified: boolean,  // true after verification
  
  // Timestamps
  createdAt: timestamp,
  confirmedAt: timestamp,  // Set when OTP verified
  updatedAt: timestamp
}
```

## Test Scenarios

### Scenario 1: Successful Booking Flow
1. Farmer books vehicle → Sees OTP
2. Farmer shares OTP with owner
3. Owner enters correct OTP
4. Both see "Confirmed" status ✅

### Scenario 2: Wrong OTP
1. Farmer books vehicle → Sees OTP
2. Farmer shares OTP with owner
3. Owner enters wrong OTP
4. Error message shown, status remains "Pending" ✅

### Scenario 3: Real-Time Confirmation
1. Farmer opens "My Bookings" page
2. Owner verifies OTP in another session
3. Farmer's page updates automatically
4. Farmer sees "Booking Confirmed!" ✅

## Troubleshooting

### Issue: OTP Not Showing for Farmer
- Check booking was created successfully
- Verify OTP field exists in Firestore document
- Check browser console for errors

### Issue: Owner Not Seeing Bookings
- Verify owner is logged in with correct account
- Check vehicleOwnerId matches owner's userId
- Ensure Firestore indexes are created

### Issue: Status Not Updating
- Check internet connection
- Verify Firestore permissions
- Check StreamBuilder is listening to correct collection

### Issue: Real-Time Updates Not Working
- Ensure using StreamBuilder (not FutureBuilder)
- Check Firestore security rules allow read access
- Verify .snapshots() is used in query

## Security Notes

### Current Implementation
- OTP is visible in Firestore documents
- Verification happens client-side
- Status updates are immediate

### Production Recommendations
1. Implement Cloud Functions for OTP email sending
2. Add rate limiting for OTP verification attempts
3. Implement OTP expiration (e.g., 24 hours)
4. Move verification logic to server-side for enhanced security
5. Encrypt OTP storage in Firestore

## Files Reference

### New Files Created
- `lib/farmer_bookings_page.dart` - Farmer booking management
- `lib/owner_bookings_page.dart` - Owner booking management
- `BOOKING_FLOW_GUIDE.md` - This guide

### Modified Files
- `lib/services/booking_service.dart` - OTP generation & verification
- `lib/booking_page.dart` - OTP display dialog
- `lib/home_page.dart` - Added booking links for both roles

## Quick Start

### As a Farmer
1. Login → Go to "Find Vehicles"
2. Select vehicle → Book it
3. Copy OTP from dialog
4. Share OTP with owner
5. Check "My Bookings" for confirmation

### As an Owner
1. Login → Go to "My Bookings"
2. Find pending booking
3. Ask farmer for OTP
4. Enter OTP in input field
5. See confirmation when successful

---

**Note:** This system uses real-time Firestore updates, so both parties see status changes instantly without manual refresh.



