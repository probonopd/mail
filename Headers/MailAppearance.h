/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-2.0-or-later
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

//
// The look that all windows and panels of the application share.  The windows
// come from nibs that were drawn with 9 and 10 point controls; here they are
// brought to the sizes of the Gershwin metrics, once per window, after the
// nib is loaded.
//
@interface MailAppearance : NSObject

//
// Scales the window and everything in it up to the system font size and gives
// its table views the standard rows.  Asked a second time for the same window
// it does nothing.
//
+ (void) styleWindow: (NSWindow *) theWindow;

//
// The factor by which the controls in a view tree have to grow to reach the
// system font size, from the font that most of them are set in.
//
+ (CGFloat) scaleFactorForView: (NSView *) theView;

@end
