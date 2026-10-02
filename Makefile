.PHONY: all freya

PORT := $(firstword $(MAKECMDGOALS))

# usage:
# make 32322 all



all:
ifeq ($(strip $(PORT)),all)
	@echo "do sth without port (Running default 'all')"
else ifeq ($(strip $(PORT)),)
	@echo "do sth without port (Port is empty)"
	flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons
else
	@echo "do sth with port: $(PORT)"
	adb connect 192.168.31.105:$(PORT)
	adb -s 192.168.31.105:$(PORT) install build/app/outputs/flutter-apk/app-release.apk
endif

freya: freya/ch001.md
	unzip -o -d freya ~/Downloads/freya-cycle.zip
	rm -f ~/Downloads/freya-cycle.zip
	cd freya; git commit -am '-'
	dart test/book2dart.dart

# flutter build macos
# flutter build apk, remove: android-arm,android-x86_64
# flutter build apk --release --target-platform android-arm64

lib/data/modle.g.dart: lib/data/modle.dart
	dart run build_runner build --force-jit

lib/riverpod_dependencies.json:
	dart run riverpod_devtools:analyze

# Catch-all rule so make doesn't look for a file named after the port number
%:
	@:
