all:
	# flutter build macos
	# flutter build apk, remove: android-arm,android-x86_64
	flutter build apk --release --target-platform android-arm64
