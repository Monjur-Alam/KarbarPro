# Google Cloud Console Setup Guide

This guide will walk you through setting up Google Sign-In and Google Drive API for the Amar Dokan application.

## Prerequisites

- A Google account
- Flutter development environment set up
- The Amar Dokan project cloned/downloaded

## Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click on the project dropdown at the top
3. Click **"New Project"**
4. Enter project name: `Amar Dokan` (or your preferred name)
5. Click **"Create"**

## Step 2: Enable Required APIs

1. In the Google Cloud Console, select your project
2. Go to **"APIs & Services"** > **"Library"**
3. Search for and enable the following APIs:
   - **Google Sign-In API** (or Google+ API)
   - **Google Drive API**

## Step 3: Configure OAuth Consent Screen

1. Go to **"APIs & Services"** > **"OAuth consent screen"**
2. Select **"External"** user type
3. Click **"Create"**
4. Fill in the required fields:
   - **App name**: Amar Dokan
   - **User support email**: Your email
   - **Developer contact information**: Your email
5. Click **"Save and Continue"**
6. On the Scopes page, click **"Add or Remove Scopes"**
7. Add the following scopes:
   - `../auth/userinfo.email`
   - `../auth/userinfo.profile`
   - `../auth/drive.file`
8. Click **"Save and Continue"**
9. Add test users (your Google account email)
10. Click **"Save and Continue"**

## Step 4: Create OAuth 2.0 Credentials

### For Android

1. Go to **"APIs & Services"** > **"Credentials"**
2. Click **"Create Credentials"** > **"OAuth client ID"**
3. Select **"Android"** as application type
4. Enter package name: `com.munjuralam.karbarpro` (or your package name from `android/app/build.gradle`)
5. Get your SHA-1 fingerprint:
   ```bash
   # For debug builds
   cd android
   ./gradlew signingReport
   ```
   Copy the SHA-1 fingerprint from the output
6. Paste the SHA-1 fingerprint in the console
7. Click **"Create"**

### For iOS

1. Click **"Create Credentials"** > **"OAuth client ID"**
2. Select **"iOS"** as application type
3. Enter bundle ID: `com.example.amarDokan` (or your bundle ID from `ios/Runner/Info.plist`)
4. Click **"Create"**
5. Download the configuration file (you'll need the iOS URL scheme)

### For Web (Optional - for testing)

1. Click **"Create Credentials"** > **"OAuth client ID"**
2. Select **"Web application"** as application type
3. Add authorized JavaScript origins:
   - `http://localhost`
4. Add authorized redirect URIs:
   - `http://localhost`
5. Click **"Create"**

## Step 5: Configure Android

1. Open `android/app/build.gradle`
2. Note your `applicationId` (should match the package name used in OAuth setup)
3. No additional configuration needed for basic Google Sign-In

**Optional**: If you want to use Firebase (recommended for production):
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/` directory
3. Add Google Services plugin to `android/build.gradle` and `android/app/build.gradle`

## Step 6: Configure iOS

1. Open `ios/Runner/Info.plist`
2. Add the following before the last `</dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your REVERSED_CLIENT_ID from Google Cloud Console -->
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

3. Replace `YOUR-CLIENT-ID` with your actual iOS client ID (reversed)
   - Find this in Google Cloud Console under your iOS OAuth client
   - Or use the format: `com.googleusercontent.apps.[YOUR_IOS_CLIENT_ID]`

## Step 7: Update Package Name (if needed)

If you changed the package name:

### Android
1. Edit `android/app/build.gradle`
2. Update `applicationId` under `defaultConfig`

### iOS
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner project
3. Update Bundle Identifier in General tab

## Step 8: Test the Application

### On Android Emulator/Device
```bash
flutter run
```

### On iOS Simulator/Device (macOS only)
```bash
flutter run -d ios
```

### On Chrome (for quick testing)
```bash
flutter run -d chrome
```

## Troubleshooting

### "Sign in failed" or "PlatformException"
- Verify SHA-1 fingerprint matches
- Check package name/bundle ID matches OAuth credentials
- Ensure APIs are enabled in Google Cloud Console
- Wait a few minutes after creating credentials (propagation delay)

### "Access denied" when saving to Drive
- Verify Drive API is enabled
- Check that the Drive scope is included in OAuth consent screen
- Re-authenticate after adding scopes

### iOS build errors
- Run `cd ios && pod install`
- Clean build: `flutter clean && flutter pub get`
- Verify Info.plist URL scheme is correct

### Android build errors
- Check `minSdkVersion` is at least 21 in `android/app/build.gradle`
- Run `cd android && ./gradlew clean`

## Important Notes

- **Development vs Production**: The OAuth consent screen will show a warning for unverified apps. For production, you'll need to verify your app with Google.
- **Test Users**: While in testing mode, only test users added in OAuth consent screen can sign in.
- **API Quotas**: Be aware of Google Drive API quotas for your project.

## Next Steps

After completing this setup:
1. Run `flutter pub get` to ensure all dependencies are installed
2. Test Google Sign-In functionality
3. Test Google Drive save functionality
4. Verify data appears in your Google Drive

## Support

If you encounter issues:
- Check [Google Sign-In Flutter documentation](https://pub.dev/packages/google_sign_in)
- Check [Google Drive API documentation](https://developers.google.com/drive/api/guides/about-sdk)
- Review Google Cloud Console logs for API errors
