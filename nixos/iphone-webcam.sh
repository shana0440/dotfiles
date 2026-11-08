# Dependencies and IPHONE_WEBCAM_HELPER are supplied by iphone-webcam.nix.
# Keep the supervisor in the foreground so Ctrl+C/terminal close also stops OBS.
exec python3 "$IPHONE_WEBCAM_HELPER" "$@"
