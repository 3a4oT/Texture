//
//  ASLayout+IGListDiffKit.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

// IGListDiffKit integration is always available in binary XCFramework distribution
#if __has_include(<IGListDiffKit/IGListDiffKit.h>)
#import <AsyncDisplayKit/ASLayout.h>
#import <IGListDiffKit/IGListDiffKit.h>

@interface ASLayout(IGListDiffKit) <IGListDiffable>
@end
#endif // __has_include(<IGListDiffKit/IGListDiffKit.h>)
