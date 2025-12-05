# Firebase Index Setup for Bookings

## The Error
Both Owner and Farmer "My Bookings" pages require Firestore composite indexes.

## Quick Fix: Create Indexes Manually

### Option 1: Use the Error Message Link
When you see the error in the app, click the provided link to automatically create the index.

### Option 2: Create Indexes Manually in Firebase Console

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project: `agritest1-172c9`
3. Navigate to Firestore Database → Indexes tab
4. Click "Create Index"

#### For Owner Bookings:
- Collection: `bookings`
- Fields to index:
  1. `vehicleOwnerId` - Ascending
  2. `createdAt` - Descending

#### For Farmer Bookings:
- Collection: `bookings`
- Fields to index:
  1. `customerId` - Ascending
  2. `createdAt` - Descending

5. Click "Create"

## Index Creation URLs

### Owner Bookings Index:
```
https://console.firebase.google.com/v1/r/project/agritest1-172c9/firestore/indexes?create_composite=ClBwcm9qZWN0cy9hZ3JpdGVzdDEtMTcyYzkvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2Jvb2tpbmdzL2luZGV4ZXMvXxABGhIKDnZlaGljbGVPd25lcklkEAEaDQoJY3JlYXRlZEF0EAIaDAoIX19uYW1FX18QAg
```

### Farmer Bookings Index:
```
https://console.firebase.google.com/v1/r/project/agritest1-172c9/firestore/indexes?create_composite=ClBwcm9qZWN0cy9hZ3JpdGVzdDEtMTcyYzkvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2Jvb2tpbmdzL2luZGV4ZXMvXxABGhAKCmN1c3RvbWVySWQQARoNCgljcmVhdGVkQXQQAhoMCghfX25hbUVfXxAC
```

## Wait Time
Index creation usually takes 1-5 minutes. Once created, refresh the app and the error will disappear.

## Alternative: Temporary Workaround

If you need to test immediately, you can comment out the `orderBy` clause temporarily:

In `lib/owner_bookings_page.dart` and `lib/farmer_bookings_page.dart`:
Change from:
```dart
.orderBy('createdAt', descending: true)
```

To:
```dart
// .orderBy('createdAt', descending: true)  // Temporarily disabled
```

Then sort in app code if needed. But creating the index is the proper solution.



