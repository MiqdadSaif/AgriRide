# Google Maps Integration Setup

This guide will help you set up Google Maps integration for the Agri Vehicle Rental app.

## Prerequisites

1. A Google Cloud Platform account
2. A Google Maps API key with the following APIs enabled:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Geocoding API

## Setup Steps

### 1. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Geocoding API
4. Go to "Credentials" and create a new API key
5. Restrict the API key to your app's package name for security

### 2. Configure the App

#### Update Configuration File
1. Open `lib/config.dart`
2. Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key:
   ```dart
   static const String googleMapsApiKey = 'your_actual_api_key_here';
   ```

#### Update Android Configuration
1. Open `android/app/src/main/AndroidManifest.xml`
2. Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="your_actual_api_key_here" />
   ```

#### Update iOS Configuration (if needed)
1. Open `ios/Runner/AppDelegate.swift`
2. Add the following import at the top:
   ```swift
   import GoogleMaps
   ```
3. Add the following line in the `application` method:
   ```swift
   GMSServices.provideAPIKey("your_actual_api_key_here")
   ```

### 3. Install Dependencies

Run the following command to install the new dependencies:

```bash
flutter pub get
```

### 4. Test the Integration

1. Run the app on a device or emulator
2. Try adding a new vehicle and selecting a location
3. Check the nearby vehicles page for map view and search functionality

## Features Added

### Location Selection
- Interactive map for selecting vehicle locations
- Search functionality using Google Places API
- Current location detection
- Address autocomplete

### Nearby Vehicles
- Map view showing vehicle locations with markers
- Search functionality for vehicles, owners, and drivers
- Filter by vehicle type and status
- Distance calculation and sorting
- Toggle between list and map views

### Search and Filter Options
- Search by vehicle description, owner name, or driver name
- Filter by vehicle type (Tractor, Tiller, Harvester, Sprayer)
- Filter by vehicle status (In Good Condition, In Repair)
- Clear filters functionality

## Security Notes

- Never commit your API key to version control
- Use environment variables or secure configuration for production
- Restrict your API key to specific apps and APIs
- Monitor API usage in Google Cloud Console

## Troubleshooting

### Common Issues

1. **Maps not loading**: Check if the API key is correctly set in both `config.dart` and `AndroidManifest.xml`
2. **Places search not working**: Ensure Places API is enabled for your project
3. **Location permission denied**: Check device location settings and app permissions
4. **Build errors**: Run `flutter clean` and `flutter pub get` after adding dependencies

### Debug Steps

1. Check the console for error messages
2. Verify API key restrictions
3. Test on a physical device (location features work better on real devices)
4. Check network connectivity

## Support

If you encounter any issues, check the Flutter Google Maps documentation or Google Maps Platform documentation for troubleshooting guides.




