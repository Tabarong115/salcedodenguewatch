# How to Test Salcedo Dengue Watch on Android

This guide will help you test the Salcedo Dengue Watch app on an Android device.

## Prerequisites

Before you begin, make sure you have:

1. **An Android phone or tablet** (Android 5.0 Lollipop or higher)
2. **USB cable** to connect your device to your computer
3. **Developer options enabled** on your Android device
4. **USB debugging enabled** on your Android device

## Step 1: Enable Developer Options on Your Android Device

1. Go to **Settings** > **About Phone**
2. Tap **Build Number** 7 times until you see "You are now a developer!"
3. Go back to **Settings** and you'll see **Developer Options** near the bottom

## Step 2: Enable USB Debugging

1. Go to **Settings** > **Developer Options**
2. Find **USB Debugging** and turn it ON
3. When prompted, allow USB debugging

## Step 3: Connect Your Device

1. Connect your Android device to your computer using a USB cable
2. On your device, you may see a prompt asking "Allow USB debugging?" - tap **Allow**

## Step 4: Verify Connection

On your computer, open a command prompt/terminal and run:

```bash
adb devices
```

You should see your device listed. If not, check your USB connection and USB debugging setting.

## Step 5: Build and Install the App

### Option A: If you have Flutter installed

1. Navigate to the project folder:
   ```bash
   cd salcedo_dengue_watch
   ```

2. Run the app on your device:
   ```bash
   flutter run
   ```

3. Or build an APK file:
   ```bash
   flutter build apk --release
   ```
   The APK will be in: `build/app/outputs/flutter-apk/app-release.apk`

### Option B: If you don't have Flutter installed

The APK file should already be built. Look for:
- `build/app/outputs/flutter-apk/app-release.apk`

To install it manually:
1. Copy the APK file to your Android device
2. On your device, find the APK file and tap it
3. You may need to allow installation from unknown sources in Settings
4. Follow the installation prompts

## Step 6: Test the App

### Public View Testing (No Login Required)

1. **Open the app** - you should see the public dashboard
2. **Check the activity level** - should show current dengue activity
3. **Tap "Activity Map"** - should show the map placeholder with demo notice
4. **Tap "Trends & Timeline"** - should show charts and statistics
5. **Tap "Health Alert"** - fill out the form and submit
   - Verify you get a reference number
   - Check the emergency warning appears
6. **Tap "Prevention Guide"** - should show 4S strategy information
7. **Test language switch** - tap the language icon to switch between English and Filipino

### Staff View Testing (Requires Login)

1. On the public dashboard, look for a login option (or navigate via menu)
2. **Test login with sample credentials** (these will need to be set up in Supabase):
   - Email: `admin@salcedo.doh.gov.ph`
   - Password: (you'll need to set this in Supabase)
3. **Staff Dashboard**:
   - Check that you see the welcome card with your name
   - Verify quick stats show numbers
   - Check priority tasks are visible
4. **Test Case Report**:
   - Tap "New Case Report"
   - Fill in all required fields
   - Try saving as draft
   - Try submitting
5. **Test Response Activity**:
   - Tap "Response Activities"
   - Fill in activity details
   - Submit and verify success message

### Admin View Testing

1. Login with admin credentials
2. **Admin Dashboard**:
   - Check overview statistics
   - Verify admin action cards are visible
3. Test each admin function (these are placeholders in current version)

## Testing Checklist

### Functionality
- [ ] App opens without crashing
- [ ] Public dashboard loads and displays data
- [ ] All public screens are accessible
- [ ] Health alert form submits successfully
- [ ] Language switch works correctly
- [ ] Staff login works (with valid credentials)
- [ ] Staff dashboard loads
- [ ] Case report form validates inputs
- [ ] Draft saving works
- [ ] Response activity logging works
- [ ] Admin dashboard loads (for admin users)

### Privacy
- [ ] Public view does NOT show patient names
- [ ] Public view does NOT show exact addresses
- [ ] Public view does NOT show phone numbers
- [ ] Public view does NOT show exact coordinates
- [ ] Map shows aggregated data only
- [ ] Restricted identity fields are separate from public data

### User Experience
- [ ] Text is readable on small screens
- [ ] Buttons are large enough to tap
- [ ] Loading states are clear
- [ ] Error messages are helpful
- [ ] App works on slow mobile data
- [ ] Draft saving works when offline

## Known Limitations in Current Version

- **Map integration**: Shows placeholder (OpenStreetMap/MapLibre integration needed)
- **Real data**: Uses fictional sample data only
- **Authentication**: Supabase setup required for real login
- **Admin functions**: Many admin features are placeholders
- **Offline sync**: Basic implementation, needs testing

## Troubleshooting

**App won't install:**
- Make sure "Install from unknown sources" is enabled in Settings
- Check that you have enough storage space
- Try a different USB cable

**App crashes on open:**
- Check that your Android version is 5.0 or higher
- Make sure you have a stable internet connection (for data loading)
- Try reinstalling the app

**Can't see your device in adb:**
- Check USB debugging is enabled
- Try a different USB port
- Reinstall USB drivers for your device

**Login doesn't work:**
- Make sure Supabase is properly configured
- Check that user accounts are created in Supabase
- Verify your email and password are correct

## Next Steps

After testing, please provide feedback on:
1. What worked well
2. What needs improvement
3. Any bugs or issues you found
4. Suggestions for features

## Important Notes

- This is a **demo version** with fictional data
- Do NOT use for real patient data until approved by RHU/LGU
- The map is labeled as "Demo map — not for operational navigation"
- All health alerts show a disclaimer that this is not an emergency service
- Privacy features are implemented but need verification with real data

For technical support or questions, contact the development team.