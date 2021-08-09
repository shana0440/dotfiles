function android_recording
  set FILE (uuidgen).mp4
  set FILE_PATH /sdcard/$FILE

  function pull_file --on-job-exit %self --inherit-variable FILE --inherit-variable FILE_PATH
    sleep 1
    adb pull $FILE_PATH
    adb shell rm $FILE_PATH
    echo $FILE
  end

  adb shell screenrecord $FILE_PATH
end
