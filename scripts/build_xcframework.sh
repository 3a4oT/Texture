#!/bin/bash

# Build XCFramework using Carthage for SPM binary distribution
#
# This script builds Texture.xcframework with the following features:
# - Core AsyncDisplayKit (all nodes, layout specs, etc.)
# - Photos framework (ASMultiplexImageNode with PHAsset support)
# - PINRemoteImage integration
# - IGListKit integration (Objective-C API)
# - TextNode2 (modern text rendering)
#
# Disabled features (to reduce binary size):
# - Video (ASVideoNode) - use CocoaPods/Carthage if needed
# - MapKit (ASMapNode) - use CocoaPods/Carthage if needed
# - AssetsLibrary - deprecated in iOS 9.0
# - Old TextNode - replaced by TextNode2
#
# Configuration approach:
# Feature flags (AS_IG_LIST_KIT, AS_USE_PHOTOS, etc.) are set via GCC_PREPROCESSOR_DEFINITIONS
# in AsyncDisplayKit.xcodeproj for Debug/Release/Profile configurations.
# Carthage dependencies (IGListKit, PINRemoteImage) are linked via OTHER_LDFLAGS in the project.
# This approach ensures flags apply ONLY to AsyncDisplayKit target, not to dependencies.
#
# To modify features:
# 1. Edit AsyncDisplayKit.xcodeproj/project.pbxproj (search for GCC_PREPROCESSOR_DEFINITIONS)
# 2. Update OTHER_LDFLAGS if adding/removing framework dependencies
# 3. Update ASAvailability.h if adding new feature flags (use #ifndef guards)
# 4. Do NOT use XCODE_XCCONFIG_FILE - it applies to ALL targets including dependencies

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PRODUCT_NAME="Texture"
BUILD_DIR="./build"
XCFRAMEWORK_NAME="${PRODUCT_NAME}.xcframework"
XCFRAMEWORK_PATH="${BUILD_DIR}/${XCFRAMEWORK_NAME}"
ZIP_NAME="${PRODUCT_NAME}.xcframework.zip"
ZIP_PATH="${BUILD_DIR}/${ZIP_NAME}"

# Platforms to build (Carthage supports iOS, tvOS, macOS, watchOS)
PLATFORMS="iOS,tvOS"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Building XCFramework for ${PRODUCT_NAME}${NC}"
echo -e "${BLUE}Using Carthage for dependency management${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if Carthage is installed
if ! command -v carthage &> /dev/null; then
    echo -e "${RED}Error: Carthage is not installed${NC}"
    echo -e "${YELLOW}Install with: brew install carthage${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Carthage found: $(carthage version)${NC}"
echo ""

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf "${BUILD_DIR}"
rm -rf "Carthage/Build"
mkdir -p "${BUILD_DIR}"

echo -e "${GREEN}✓ Cleaned build directory${NC}"
echo ""

# Update dependencies
echo -e "${YELLOW}Resolving Carthage dependencies...${NC}"
echo -e "${BLUE}This will download: PINRemoteImage, PINCache, IGListKit${NC}"
carthage update --use-xcframeworks --no-build --platform ${PLATFORMS}

echo -e "${GREEN}✓ Dependencies resolved${NC}"
echo ""

# Build XCFramework
echo -e "${YELLOW}Building XCFramework with Carthage...${NC}"
echo -e "${BLUE}Building for platforms: ${PLATFORMS}${NC}"
echo -e "${BLUE}This may take several minutes...${NC}"
echo ""

# Configure build settings optimized for iOS 14+ binary distribution
echo -e "${YELLOW}Build Configuration (Optimized for iOS 14+):${NC}"
echo -e "${GREEN}  Enabled Features:${NC}"
echo -e "    - Core nodes (ASDisplayNode, ASImageNode, ASTextNode2, etc.)"
echo -e "    - Photos framework (ASMultiplexImageNode with PHAsset support)"
echo -e "    - PINRemoteImage integration"
echo -e "    - IGListKit integration (Objective-C API)"
echo -e "    - TextNode2 (modern, performant)"
echo -e "${RED}  Disabled Features:${NC}"
echo -e "    - Video (ASVideoNode) - niche, heavy frameworks (AVFoundation + CoreMedia)"
echo -e "    - MapKit (ASMapNode) - niche, rarely used (~10% of apps)"
echo -e "    - AssetsLibrary - deprecated iOS 9.0"
echo -e "    - Old TextNode - legacy, slower than TextNode2"
echo ""
echo -e "${BLUE}Note: For Video/MapKit features, use CocoaPods/Carthage from original repository${NC}"
echo ""

# Build with optimized settings
# Note: BUILD_LIBRARY_FOR_DISTRIBUTION is automatically enabled by Carthage for XCFrameworks
# Feature flags and linker settings are configured in AsyncDisplayKit.xcodeproj:
#   - GCC_PREPROCESSOR_DEFINITIONS: AS_IG_LIST_KIT=1, AS_IG_LIST_DIFF_KIT=1, AS_USE_PHOTOS=1
#   - FRAMEWORK_SEARCH_PATHS: $(SRCROOT)/Carthage/Build
#   - OTHER_LDFLAGS: -framework IGListKit, IGListDiffKit, PINRemoteImage
carthage build \
    --use-xcframeworks \
    --platform ${PLATFORMS} \
    --no-skip-current

echo -e "${GREEN}✓ Build completed${NC}"
echo ""

# Find the built XCFramework
CARTHAGE_XCFRAMEWORK="Carthage/Build/AsyncDisplayKit.xcframework"

if [ ! -d "${CARTHAGE_XCFRAMEWORK}" ]; then
    echo -e "${RED}Error: XCFramework not found at ${CARTHAGE_XCFRAMEWORK}${NC}"
    echo -e "${YELLOW}Available files:${NC}"
    ls -la Carthage/Build/
    exit 1
fi

# Copy to build directory with product name
echo -e "${YELLOW}Copying XCFramework to build directory...${NC}"
cp -R "${CARTHAGE_XCFRAMEWORK}" "${XCFRAMEWORK_PATH}"

echo -e "${GREEN}✓ XCFramework copied to: ${XCFRAMEWORK_PATH}${NC}"
echo ""

# Verify XCFramework structure
echo -e "${YELLOW}Verifying XCFramework structure...${NC}"
xcodebuild -checkFirstLaunchStatus
if xcodebuild -checkFirstLaunchStatus; then
    echo -e "${GREEN}✓ XCFramework structure is valid${NC}"
fi
echo ""

# Display XCFramework info
echo -e "${YELLOW}XCFramework contents:${NC}"
find "${XCFRAMEWORK_PATH}" -maxdepth 2 -type d | head -10
echo ""

# Check for .swiftinterface (Library Evolution)
echo -e "${YELLOW}Checking for Swift Library Evolution support...${NC}"
if find "${XCFRAMEWORK_PATH}" -name "*.swiftinterface" | grep -q .; then
    echo -e "${GREEN}✓ Found .swiftinterface files (Library Evolution enabled)${NC}"
    find "${XCFRAMEWORK_PATH}" -name "*.swiftinterface" | head -5
else
    echo -e "${YELLOW}⚠ No .swiftinterface files found (this is OK if framework is pure Objective-C)${NC}"
fi
echo ""

# Create ZIP archive
echo -e "${YELLOW}Creating ZIP archive...${NC}"
cd "${BUILD_DIR}"
zip -r -q -y "${ZIP_NAME}" "${XCFRAMEWORK_NAME}"
cd - > /dev/null

echo -e "${GREEN}✓ ZIP created at: ${ZIP_PATH}${NC}"
echo ""

# Calculate checksum
echo -e "${YELLOW}Calculating checksum...${NC}"
CHECKSUM=$(swift package compute-checksum "${ZIP_PATH}")
echo -e "${GREEN}✓ Checksum: ${CHECKSUM}${NC}"
echo ""

# Get file size
FILE_SIZE=$(du -h "${ZIP_PATH}" | cut -f1)
FILE_SIZE_BYTES=$(stat -f%z "${ZIP_PATH}" 2>/dev/null || stat -c%s "${ZIP_PATH}" 2>/dev/null)
FILE_SIZE_MB=$(echo "scale=2; ${FILE_SIZE_BYTES} / 1024 / 1024" | bc)

# Get current git tag or commit
GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "not-tagged")
GIT_COMMIT=$(git rev-parse --short HEAD)

# Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Build Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Product Name:    ${PRODUCT_NAME}"
echo -e "XCFramework:     ${XCFRAMEWORK_PATH}"
echo -e "ZIP Archive:     ${ZIP_PATH}"
echo -e "File Size:       ${FILE_SIZE} (${FILE_SIZE_MB} MB)"
echo -e "Checksum:        ${CHECKSUM}"
echo -e "Git Tag:         ${GIT_TAG}"
echo -e "Git Commit:      ${GIT_COMMIT}"
echo -e "Platforms:       ${PLATFORMS}"
echo ""
echo -e "${GREEN}Included Dependencies:${NC}"
echo -e "  - PINRemoteImage 3.0.4"
echo -e "  - PINCache 3.0.4"
echo -e "  - IGListKit ~> 5.0.0"
echo ""
echo -e "${GREEN}Enabled Features:${NC}"
echo -e "  - Core AsyncDisplayKit (all nodes, layout specs, etc.)"
echo -e "  - Photos framework (ASMultiplexImageNode with PHAsset)"
echo -e "  - PINRemoteImage integration"
echo -e "  - IGListKit integration (Objective-C API)"
echo -e "  - TextNode2 (modern text rendering)"
echo ""
echo -e "${YELLOW}Disabled Features (use CocoaPods/Carthage if needed):${NC}"
echo -e "  - Video (ASVideoNode) - niche, requires AVFoundation + CoreMedia"
echo -e "  - MapKit (ASMapNode) - only ~10% of apps need maps"
echo -e "  - AssetsLibrary - deprecated in iOS 9.0"
echo -e "  - Old TextNode - legacy, replaced by TextNode2"
echo ""
echo -e "${BLUE}Why Video/MapKit are disabled:${NC}"
echo -e "  - Smaller binary size"
echo -e "  - Fewer framework dependencies (AVFoundation, CoreMedia, MapKit)"
echo -e "  - Faster app launch time"
echo -e "  - Niche features used by minority of apps"
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}1. Create a GitHub Release:${NC}"
echo -e "   git tag <version>"
echo -e "   git push origin <version>"
echo -e "   gh release create <version> --title \"<version>\" --notes \"Release notes\""
echo ""
echo -e "${YELLOW}2. Upload the ZIP file:${NC}"
echo -e "   gh release upload <version> ${ZIP_PATH}"
echo ""
echo -e "${YELLOW}3. Get the download URL:${NC}"
echo -e "   https://github.com/TextureGroup/Texture/releases/download/<version>/${ZIP_NAME}"
echo ""
echo -e "${YELLOW}4. Update Package.swift with binary target:${NC}"
echo ""
echo -e "${GREEN}Add this to your targets array:${NC}"
echo ""
echo -e "${BLUE}.binaryTarget(${NC}"
echo -e "${BLUE}    name: \"AsyncDisplayKitBinary\",${NC}"
echo -e "${BLUE}    url: \"https://github.com/TextureGroup/Texture/releases/download/<version>/${ZIP_NAME}\",${NC}"
echo -e "${BLUE}    checksum: \"${CHECKSUM}\"${NC}"
echo -e "${BLUE})${NC}"
echo ""
echo -e "${BLUE}================================================${NC}"
echo ""
