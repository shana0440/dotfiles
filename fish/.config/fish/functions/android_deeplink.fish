function android_deeplink
  adb shell am start -W -a android.intent.action.VIEW -d $argv
end
