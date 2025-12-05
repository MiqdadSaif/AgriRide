# OTP-Based Booking System Guide

## Overview
This document describes the OTP (One-Time Password) based booking system implemented for the agricultural vehicle rental application.

## How It Works

### Flow Description
1. **Farmer Books a Vehicle**:
   - Farmer selects a vehicle and fills in booking details (hours, location)
   - When they submit the booking, an OTP is automatically generated
   - A dialog shows the farmer the 6-digit OTP
   - The OTP is stored in Firestore along with the booking details

2. **Vehicle Owner Verification**:
   - Vehicle owners can view pending bookings in the "My Bookings" section
   - For each pending booking, they see an OTP input field
   - Owner enters the OTP provided by the farmer
   - If the OTP matches, the booking status changes to "confirmed"
   - If the OTP is incorrect, an error message is shown

### Components

#### 1. Booking Service (`lib/services/booking_service.dart`)
**New Features:**
- `_generateOTP()`: Generates a random 6-digit OTP
- `createBooking()`: Now returns both booking ID and OTP
- `verifyOTPAndConfirmBooking()`: Verifies OTP and confirms booking
- `getBookingOTP()`: Retrieves OTP for a specific booking
- Automatically fetches vehicle owner ID from vehicle document

**Updated Features:**
- Booking documents now include:
  - `otp`: The 6-digit OTP string
  - `otpVerified`: Boolean flag indicating if OTP has been verified
  - `vehicleOwnerId`: Automatically fetched from vehicle document

#### 2. Booking Page (`lib/booking_page.dart`)
**New Features:**
- Shows OTP to farmer after successful booking creation
- `_showOTPDialog()`: Displays OTP in a modal dialog with instructions

#### 3. Owner Bookings Page (`lib/owner_bookings_page.dart`)
**New Page:**
- Lists all bookings for vehicle owners
- Shows pending bookings with OTP input field
- Displays booking details: customer info, hours, cost, location
- Allows owners to verify OTP and confirm bookings
- Shows booking status with color-coded badges
- Allows cancellation of pending bookings

#### 4. Home Page (`lib/home_page.dart`)
**Updated Features:**
- Added "My Bookings" card for vehicle owners
- Links to OwnerBookingsPage

## Firestore Schema

### Bookings Collection
```javascript
{
  vehicleId: string,
  vehicleDescription: string,
  vehicleCategory: string,
  hours: number,
  pricePerHour: number,
  totalCost: number,
  customerId: string,
  customerEmail: string,
  customerName: string,
  vehicleOwnerId: string,  // Automatically fetched
  locationText: string,
  location: {
    latitude: number,
    longitude: number
  },
  status: string,  // 'pending', 'confirmed', 'active', 'completed', 'cancelled'
  paymentStatus: string,
  emailVerified: boolean,
  otp: string,  // 6-digit OTP
  otpVerified: boolean,  // true after owner verifies
  createdAt: timestamp,
  bookingDate: string,
  updatedAt: timestamp,
  confirmedAt: timestamp  // Added when OTP is verified
}
```

## Usage Instructions

### For Farmers
1. Navigate to "Find Vehicles" from the home page
2. Select a vehicle and click "Rent Now"
3. Fill in booking details:
   - Number of hours
   - Location (use map picker or current location)
4. Click "Place Booking"
5. Copy the displayed OTP
6. Share the OTP with the vehicle owner via your preferred method (call, SMS, etc.)

### For Vehicle Owners
1. Navigate to "My Bookings" from the home page
2. View all pending bookings
3. For each pending booking:
   - Review customer details and booking information
   - Ask the farmer for the OTP
   - Enter the 6-digit OTP in the input field
   - The booking will be automatically confirmed if OTP is correct
4. Confirmed bookings show a green checkmark

## Status Codes
- **pending**: Waiting for OTP verification
- **confirmed**: OTP verified, booking confirmed
- **active**: Booking is active (can be added later)
- **completed**: Booking completed successfully
- **cancelled**: Booking was cancelled

## Security Considerations

### Current Implementation
- OTP is stored in Firestore (visible to users with access)
- OTP verification happens on the client side
- OTPs are single-use and cannot be changed after creation

### Recommended Enhancements
1. **Email Integration**: Set up Firebase Cloud Functions to send OTP via email automatically
2. **OTP Expiration**: Add expiration timestamp (e.g., 24 hours)
3. **Rate Limiting**: Limit OTP verification attempts (e.g., 3 attempts)
4. **Server-Side Verification**: Move OTP verification to Cloud Functions for better security

## Firebase Cloud Functions Setup (Future Enhancement)

To send OTP via email automatically, you would need to:

1. Install Firebase CLI and initialize Functions
2. Install nodemailer or use Firebase Extensions for email
3. Create a function triggered when a booking is created:

```javascript
exports.sendBookingOTP = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    const customerEmail = booking.customerEmail;
    const otp = booking.otp;
    
    // Send email with OTP
    await sendEmail({
      to: customerEmail,
      subject: 'Your Booking OTP',
      html: `Your OTP is: ${otp}`
    });
  });
```

## Troubleshooting

### OTP Not Showing
- Check browser console for errors
- Verify booking was created successfully in Firestore
- Ensure user has appropriate permissions

### OTP Verification Failing
- Verify OTP is entered correctly (6 digits)
- Check that OTP hasn't been verified already
- Review Firestore permissions

### Owner Not Seeing Bookings
- Verify user is logged in as vehicle owner
- Check that `vehicleOwnerId` field is set correctly in booking document
- Ensure Firestore indexes are created for the query

## Testing Checklist
- [ ] Farmer can create a booking and see OTP
- [ ] Vehicle owner can see pending bookings
- [ ] Vehicle owner can enter OTP
- [ ] Correct OTP confirms booking
- [ ] Incorrect OTP shows error
- [ ] Booking status updates correctly
- [ ] Cancellation works for pending bookings

## Notes
- OTPs are currently displayed on-screen rather than sent via email
- For production use, implement automatic email sending via Cloud Functions
- OTPs are simple 6-digit numbers - consider implementing more secure generation methods for production



