#
# Instead of one file, you will now see three:
#  app-arm64-v8a-release.apk 👈 Use this one for your Pixel. Virtually all modern Android phones use this 64-bit architecture.
#  app-armeabi-v7a-release.apk (For very old or low-end 32-bit phones).
#  app-x86_64-release.apk (For computer emulators).
#

if [[ $# -ne 0 ]]; then
   echo 'No argument is required.'
   exit 1
fi

echo '***Cleaning ...'
flutter clean
flutter pub get
flutter pub outdated

#DO NOT DO UPGRADE. IT COULD BREAK THE BUILD: echo '***Upgrading outdated packages ...'
#flutter pub upgrade

echo '***Building the Android .apk ...'
flutter build apk --release --split-per-abi
