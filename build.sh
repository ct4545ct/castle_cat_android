#!/bin/sh
# Builds PurrfectClimb.apk with the Android SDK command-line tools (no Gradle).
set -e
cd "$(dirname "$0")"

SDK="${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}"
BT="$SDK/build-tools/36.0.0"
ANDROID_JAR="$SDK/platforms/android-36/android.jar"

rm -rf build && mkdir -p build/classes build/dex build/gen

# 1. Compile and link resources
"$BT/aapt2" compile --dir res -o build/res.zip
"$BT/aapt2" link -o build/unsigned.apk -I "$ANDROID_JAR" \
  --manifest AndroidManifest.xml -A assets --java build/gen \
  build/res.zip

# 2. Compile Java
javac -nowarn -Xlint:-options -source 8 -target 8 -encoding UTF-8 \
  -bootclasspath "$ANDROID_JAR" -d build/classes \
  $(find src build/gen -name '*.java')

# 3. Dex
"$BT/d8.bat" --release --min-api 26 --lib "$ANDROID_JAR" \
  --output build/dex $(find build/classes -name '*.class')
(cd build/dex && jar uf ../unsigned.apk classes.dex)

# 4. Align and sign
"$BT/zipalign.exe" -f -p 4 build/unsigned.apk build/aligned.apk
if [ ! -f release.keystore ]; then
  keytool -genkeypair -keystore release.keystore -alias castlecat \
    -storepass castlecat123 -keypass castlecat123 -keyalg RSA -keysize 2048 \
    -validity 10000 -dname "CN=Purrfect Climb" -noprompt
fi
"$BT/apksigner.bat" sign --ks release.keystore --ks-key-alias castlecat \
  --ks-pass pass:castlecat123 --key-pass pass:castlecat123 \
  --out PurrfectClimb.apk build/aligned.apk
"$BT/apksigner.bat" verify PurrfectClimb.apk
echo "APK: $(pwd)/PurrfectClimb.apk"
