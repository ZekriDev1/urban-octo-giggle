# DeplaceToi \

## Features

### ✅ Implemented Features

1. **Animated Splash Screen**
   - Smooth fade-in and scale animations
   - DeplaceToi pink accent color theme
   - 4-second duration with automatic navigation

2. **Authentication System**
   - Sign Up and Login screens with email/password
   - Optional phone number during signup
   - Input validation (email format, password strength)
   - Supabase authentication integration
   - Persistent login sessions

3. **Home Screen with Map Integration**
   - Google Maps integration (works on both iOS and Android)
   - Real-time user location tracking
   - Destination search functionality
   - Route visualization with polylines
   - ETA and distance calculations

4. **Uber-Style UI Elements**
   - Floating action buttons (location refresh, menu)
   - Bottom sheet for ride details
   - Modern design with gradients and soft corners
   - Smooth transitions and animations
   - DeplaceToi pink accent throughout

5. **Data Management**
   - Recent addresses storage
   - Favorite locations
   - Ride history in Supabase
   - Local storage with SharedPreferences

6. **Additional Features**
   - Loading indicators with pink accent
   - Error handling and notifications
   - Clean architecture with separation of concerns
   - Scalable structure for future enhancements

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Get your project URL and anon key from the Supabase dashboard
3. Update `lib/core/constants/app_constants.dart`:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

### 3. Set Up Supabase Database

Run these SQL commands in your Supabase SQL editor:

```sql
-- Create users table
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT NOT NULL,
  name TEXT,
  phone TEXT,
  profile_picture_url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create rides table
CREATE TABLE rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  pickup_latitude DOUBLE PRECISION NOT NULL,
  pickup_longitude DOUBLE PRECISION NOT NULL,
  pickup_address TEXT NOT NULL,
  destination_latitude DOUBLE PRECISION NOT NULL,
  destination_longitude DOUBLE PRECISION NOT NULL,
  destination_address TEXT NOT NULL,
  fare DOUBLE PRECISION,
  status TEXT NOT NULL DEFAULT 'pending',
  driver_id UUID,
  estimated_duration INTEGER,
  distance DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rides ENABLE ROW LEVEL SECURITY;

-- Create policies for users table
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Create policies for rides table
CREATE POLICY "Users can view own rides"
  ON rides FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own rides"
  ON rides FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own rides"
  ON rides FOR UPDATE
  USING (auth.uid() = user_id);
```

### 4. Add Your Logo

Place your DeplaceToi logo at:
```
assets/images/logo.png
```

The app will use this logo in the splash screen. If the logo is not found, it will display a default car icon.

### 5. Configure Google Maps (for Android)

1. Get a Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Add to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
   ```

### 6. Configure Google Maps (for iOS)

1. Add to `ios/Runner/AppDelegate.swift`:
   ```swift
   import GoogleMaps
   
   // In application:didFinishLaunchingWithOptions:
   GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
   ```

2. Add to `ios/Runner/Info.plist`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>We need your location to provide ride services</string>
   <key>NSLocationAlwaysUsageDescription</key>
   <string>We need your location to provide ride services</string>
   ```

### 7. Configure Location Permissions (Android)

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

## Project Structure

```
lib/
├── core/
│   ├── constants/      # App constants and colors
│   └── theme/          # Theme configuration
├── models/             # Data models
├── providers/          # State management (Provider)
├── screens/
│   ├── auth/           # Login and Signup screens
│   ├── home/           # Home screen with map
│   └── splash/         # Splash screen
├── services/           # Business logic services
│   ├── location_service.dart
│   ├── storage_service.dart
│   └── supabase_service.dart
└── widgets/            # Reusable widgets
```

## Color Theme

The app uses DeplaceToi pink accent color:
- Primary Pink: `#FF1493` (DeepPink)
- Primary Pink Light: `#FF69B4` (HotPink)
- Primary Pink Dark: `#C71585` (MediumVioletRed)

## Running the App

```bash
# Run on connected device
flutter run

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android
```

## Future Enhancements

The app is structured to easily add:
- Driver panel
- Real-time ride tracking
- Payment integration
- Push notifications
- In-app chat
- Ride sharing options

## Dependencies

- `supabase_flutter`: Authentication and database
- `google_maps_flutter`: Map integration
- `geolocator`: Location services
- `geocoding`: Address geocoding
- `provider`: State management
- `shared_preferences`: Local storage
- `image_picker`: Profile picture upload
- `animations`: Smooth animations

## Notes

- The app uses Google Maps which works on both iOS and Android
- For a true Apple Maps experience on iOS, you can integrate the native Apple Maps SDK separately
- All user data is stored securely in Supabase
- Recent addresses and favorites are stored locally for offline access

## License

This project is private and proprietary.
