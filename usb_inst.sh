#
# pass the phone's IP address & port as $1
#
# TO get the crash log files from the mobile device:
# on laptop: run adb logcat *:E | grep -i "flutter\|fatal\|exception"
#
# Two ways to do a remote install:
# 1) phone connected via USB to the laptop
#    not tested: adb install 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
# 2) phone is on the same WiFi as the laptop
#    run adb pair & adb connect on the phone
#    adb -s <phone's IP_address:port>  install 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
#if [[ $# -ne 1 ]]; then
   #echo "Requires one argument. Format: phone_ip_addr:port"
   #exit 1
#fi
echo "Started the install"
adb install 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
echo "Done"
