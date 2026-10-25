# Default target when running just `make`
.PHONY: all
build/app/outputs/flutter-apk/app-release.apk: lib/*.dart lib/ui/*.dart
	@flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons

# Handle numeric arguments like `make 5` or `make 42`
# If the argument is an integer, it echos that integer.
# Otherwise, it falls back to treating it as a standard make target.
%:
	@if [ "$@" -eq "$@" ] 2>/dev/null; then \
		echo connect to 192.168.1.190:$@; \
		adb connect 192.168.1.190:"$@"; \
		adb -s 192.168.1.190:"$@" install build/app/outputs/flutter-apk/app-release.apk; \
	else \
		$(MAKE) -f $(MAKEFILE_LIST) build-$@; \
	fi

# Define your custom compilation targets below (e.g., `make target` -> `make build-target`)
build-target:
	@echo "Compiling target..."
	# Add your actual compilation commands here, for example:
	# gcc -o target target.c



.PHONY: all freya

PORT := $(firstword $(MAKECMDGOALS))

build-freya: freya/ch001.md
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
