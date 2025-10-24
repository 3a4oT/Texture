#!/bin/bash
# echo ************* diagnostics
# echo available devices
# instruments -s devices
# echo available sdk
# xcodebuild -showsdks
# echo available Xcode
# ls -ld /Applications/Xcode*
# echo ************* diagnostics end

# run this on a 2x device until we've updated snapshot images to 3x
PLATFORM="${TEXTURE_BUILD_PLATFORM:-platform=iOS Simulator,OS=26.0,name=iPhone 17}"
SDK="${TEXTURE_BUILD_SDK:-iphonesimulator26.0}"
DERIVED_DATA_PATH="~/ASDKDerivedData"

# It is pitch black.
set -e
function trap_handler {
    echo -e "\n\nOh no! You walked directly into the slavering fangs of a lurking grue!"
    echo "**** You have died ****"
    exit 255
}
trap trap_handler INT TERM EXIT

# Derived data handling
eval [ ! -d $DERIVED_DATA_PATH ] && eval mkdir $DERIVED_DATA_PATH
function clean_derived_data {
    eval find $DERIVED_DATA_PATH -mindepth 1 -delete
}

# Ensure Carthage dependencies are built
function ensure_carthage_dependencies {
    if [ ! -d "Carthage/Build" ]; then
        echo "Building Carthage dependencies (required for AsyncDisplayKit.xcodeproj)..."
        carthage update --no-use-binaries --no-build --platform iOS
        carthage build --no-skip-current --use-xcframeworks --platform iOS
    fi
}

MODE="$1"

case "$MODE" in
carthage|all)
    echo "Verifying carthage works."

    set -o pipefail && carthage update --no-use-binaries --no-build && carthage build --no-skip-current --use-xcframeworks
    success="1"
    ;;

spm|all)
    echo "Verifying Swift Package Manager works."

    ensure_carthage_dependencies

    # Generate SPM symlinks
    echo "Generating SPM layout..."
    swift scripts/generate_spm_sources_layout.swift

    # Build with default traits
    echo "Building with default traits..."
    set -o pipefail && xcodebuild \
        -scheme AsyncDisplayKit \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        clean build
    success="1"
    ;;

spm-texture-basic)
    echo "Testing SPMBasic example (verifying committed SPM layout)."

    # DO NOT regenerate - test that committed spm/Sources is valid
    echo "Using committed SPM layout (no regeneration)..."

    # Test SPMBasic example (build and test)
    echo "Building and testing SPMBasic example..."
    cd examples/SPMBasic
    set -o pipefail && xcodebuild \
        -scheme SPMBasic \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        clean build test
    cd ../..

    success="1"
    ;;

spm-texture-iglistkit)
    echo "Testing SPMWithIGListKit example (testing SPM generation script)."

    # Clean and regenerate to verify generation script works
    echo "Cleaning generated SPM directory..."
    rm -rf spm/Sources

    echo "Generating SPM layout from scratch..."
    swift scripts/generate_spm_sources_layout.swift

    # Test SPMWithIGListKit example (build and test)
    echo "Building and testing SPMWithIGListKit example..."
    cd examples/SPMWithIGListKit
    set -o pipefail && xcodebuild \
        -scheme SPMWithIGListKit \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        clean build test
    cd ../..

    success="1"
    ;;

spm-app-iglistkit)
    echo "Testing ASIGListKitSPM iOS app example (local package wrapper approach)."

    # DO NOT regenerate - reuse SPM layout from previous tests

    # Test ASIGListKitSPM iOS app example (build only)
    echo "Building ASIGListKitSPM iOS app example..."
    cd examples/ASIGListKitSPM
    set -o pipefail && xcodebuild \
        -scheme ASIGListKitSPM \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        clean build
    cd ../..

    success="1"
    ;;

*)
    echo "Unrecognized mode '$MODE'."
    ;;
esac

if [ "$success" = "1" ]; then
  trap - EXIT
  exit 0
fi
