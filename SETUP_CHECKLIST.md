# Setup Checklist

Use this checklist to ensure your DeplaceToi app is properly configured before running.

## ✅ Required Setup Steps

### 1. Dependencies
- [ ] Run `flutter pub get` to install all dependencies

### 2. Supabase Configuration
- [ ] Create a Supabase project at [supabase.com](https://supabase.com)
- [ ] Get your project URL and anon key
- [ ] Update `lib/core/constants/app_constants.dart` with your Supabase credentials:
  ```dart
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  ```

### 3. Supabase Database Setup
- [ ] Run the SQL commands from README.md in your Supabase SQL editor
- [ ] Verify tables are created: `users` and `rides`
- [ ] Verify Row Level Security (RLS) policies are active

### 4. Logo Asset
- [ ] Place your DeplaceToi logo at `assets/images/logo.png`
- [ ] Recommended size: 512x512 or 1024x1024 pixels
- [ ] Format: PNG with transparency

### 5. Google Maps API Key (Android)
- [ ] Get a Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
- [ ] Update `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
  ```

### 6. Google Maps API Key (iOS)
- [ ] Add Google Maps SDK to your iOS project
- [ ] Update `ios/Runner/AppDelegate.swift` with your API key
- [ ] Ensure location permissions are configured (already done in Info.plist)

### 7. Test the App
- [ ] Run `flutter run` on a connected device or emulator
- [ ] Test sign up flow
- [ ] Test login flow
- [ ] Test location permissions
- [ ] Test map display
- [ ] Test destination search
- [ ] Test ride request

## 🎨 Customization

### Change Pink Accent Color
To change the DeplaceToi pink accent color, update `lib/core/constants/app_colors.dart`:
```dart
static const Color primaryPink = Color(0xFFFF1493); // Change this hex value
```

### Adjust Splash Screen Duration
Update `lib/core/constants/app_constants.dart`:
```dart
static const Duration splashDuration = Duration(seconds: 4); // Change duration
```

## 📱 Platform-Specific Notes

### Android
- Location permissions are already configured
- Google Maps API key needs to be added
- Minimum SDK version: Check `android/app/build.gradle.kts`

### iOS
- Location permissions are already configured in Info.plist
- Google Maps SDK needs to be added via CocoaPods
- Run `cd ios && pod install` after adding dependencies

## 🐛 Troubleshooting

### Map not showing
- Verify Google Maps API key is correctly set
- Check that location permissions are granted
- Ensure internet connection is active

### Authentication not working
- Verify Supabase URL and anon key are correct
- Check Supabase dashboard for any errors
- Ensure database tables are created

### Location not updating
- Grant location permissions when prompted
- Check device location settings
- Verify location services are enabled

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Supabase Documentation](https://supabase.com/docs)
- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [Provider State Management](https://pub.dev/packages/provider)

