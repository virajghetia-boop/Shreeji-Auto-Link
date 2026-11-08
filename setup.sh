#!/usr/bin/env bash
# Run once from the project root (folder that contains lib/, assets/, pubspec.yaml).
# It generates the Android platform files and applies the required patches.
set -e
cp pubspec.yaml /tmp/pubspec.keep
flutter create --org com.shreeji --project-name shreeji_autolink --platforms=android .
cp /tmp/pubspec.keep pubspec.yaml
rm -f test/widget_test.dart

# minSdk 24 (needed by local_auth / biometrics)
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/; s/minSdkVersion flutter.minSdkVersion/minSdkVersion 24/' android/app/build.gradle* 2>/dev/null || true

MAN=android/app/src/main/AndroidManifest.xml
grep -q USE_BIOMETRIC $MAN || sed -i 's|<manifest xmlns:android="http://schemas.android.com/apk/res/android">|&\n    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>|' $MAN
sed -i 's/android:label="[^"]*"/android:label="Shreeji Autolink"/' $MAN

# biometrics need FlutterFragmentActivity + AppCompat theme
MAIN=$(find android/app/src/main -name 'MainActivity.*' | head -n1)
rm -f "$MAIN"
KDIR=android/app/src/main/kotlin/com/shreeji/shreeji_autolink
mkdir -p $KDIR
cat > $KDIR/MainActivity.kt <<'KT'
package com.shreeji.shreeji_autolink

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
KT
for f in android/app/src/main/res/values/styles.xml android/app/src/main/res/values-night/styles.xml; do
  [ -f "$f" ] && sed -i 's|parent="@android:style/Theme.Light.NoTitleBar"|parent="Theme.AppCompat.Light.NoActionBar"|; s|parent="@android:style/Theme.Black.NoTitleBar"|parent="Theme.AppCompat.NoActionBar"|' "$f"
done

flutter pub get
dart run flutter_launcher_icons
echo "SETUP DONE. Now run:  flutter build apk --release"
