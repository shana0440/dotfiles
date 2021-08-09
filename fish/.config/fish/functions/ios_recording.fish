function ios_recording
  set MP4_FILE (uuidgen).mp4
  xcrun simctl io booted recordVideo --codec=h264 --mask=black $MP4_FILE
end
