// BinaryWrapper.swift
//
// This file exists to satisfy Swift Package Manager's requirement that targets
// must contain at least one source file. This wrapper target links the
// AsyncDisplayKitBinary (XCFramework) with SPM dependencies (PINRemoteImage, IGListKit).
//
// Users should import AsyncDisplayKit in their code, not this module.

// Re-export AsyncDisplayKit from the binary XCFramework
// This makes all Objective-C classes (including ASIGListSectionControllerMethods) visible to Swift
@_exported import AsyncDisplayKit

// Re-export IGListKit modules to satisfy framework header imports
// The binary framework includes headers that import these modules:
// - ASLayout+IGListDiffKit.h imports <IGListDiffKit/IGListDiffKit.h>
// - AsyncDisplayKit+IGListKitMethods.h imports <IGListKit/IGListKit.h>
// - IGListAdapter+AsyncDisplayKit.h imports <IGListKit/IGListKit.h>
// Without re-exporting these modules, Xcode cannot resolve the imports when using binary distribution
@_exported import IGListKit
@_exported import IGListDiffKit
