/*
**  MailboxManagerController+Appearance.m
**
**  The look of the mailboxes window: the list of mailboxes across the whole
**  window, and below it a bar with the buttons that make and remove a mailbox.
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#import "MailboxManagerController.h"

#import <AppKit/AppKit.h>

#import "AppearanceMetrics.h"

// The bar at the bottom of the window; the buttons are 28 wide and as high as
// the metrics say, one pixel of outline is shared by the two of them.
#define BAR_HEIGHT 28.0
#define MINI_BUTTON_WIDTH 28.0

@interface MailboxManagerController (AppearancePrivate)
- (NSButton *) _miniButtonWithTitle: (NSString *) theTitle
			     action: (SEL) theAction
			    toolTip: (NSString *) theToolTip
				  x: (CGFloat) theX;
@end


@implementation MailboxManagerController (Appearance)

- (void) applyAppearance
{
  NSScrollView *aScrollView;
  NSView *aContentView;
  NSRect aBounds;
  NSArray *allSubviews;
  NSUInteger i;

  aContentView = [[self window] contentView];
  aBounds = [aContentView bounds];
  aScrollView = [outlineView enclosingScrollView];

  // Getting the mail is in the toolbar of the message window and in the
  // Mailbox menu; the button that was here is not needed any more.
  allSubviews = [NSArray arrayWithArray: [aContentView subviews]];

  for (i = 0; i < [allSubviews count]; i++)
    {
      NSView *aView;

      aView = [allSubviews objectAtIndex: i];

      if ([aView isKindOfClass: [NSButton class]])
	{
	  [aView removeFromSuperview];
	}
      else if ([aView isKindOfClass: [NSBox class]])
	{
	  // The nib puts the list in a box with a frame.
	  [(NSBox *)aView setBorderType: NSNoBorder];
	}
    }

  // The list is where the box held it; it moves out to fill the window.
  [aScrollView removeFromSuperview];
  [aContentView addSubview: aScrollView];
  [aScrollView setFrame: NSMakeRect(0, BAR_HEIGHT, NSWidth(aBounds), NSHeight(aBounds) - BAR_HEIGHT)];
  [aScrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [aScrollView setBorderType: NSNoBorder];
  [aScrollView setHasHorizontalScroller: NO];

  [aContentView addSubview: [self _miniButtonWithTitle: @"+"
						action: @selector(create:)
					       toolTip: _(@"Create...")
						     x: METRICS_SPACE_8]];
  [aContentView addSubview: [self _miniButtonWithTitle: @"-"
						action: @selector(delete:)
					       toolTip: _(@"Delete...")
						     x: METRICS_SPACE_8 + MINI_BUTTON_WIDTH - 1]];
}


- (NSButton *) _miniButtonWithTitle: (NSString *) theTitle
			     action: (SEL) theAction
			    toolTip: (NSString *) theToolTip
				  x: (CGFloat) theX
{
  NSButton *aButton;

  aButton = [[NSButton alloc] initWithFrame: NSMakeRect(theX, (BAR_HEIGHT - METRICS_BUTTON_HEIGHT) / 2, MINI_BUTTON_WIDTH, METRICS_BUTTON_HEIGHT)];
  [aButton setBezelStyle: NSRegularSquareBezelStyle];
  [aButton setTitle: theTitle];
  [aButton setFont: METRICS_FONT_SYSTEM_REGULAR_13];
  [aButton setTarget: self];
  [aButton setAction: theAction];
  [aButton setToolTip: theToolTip];
  [aButton setAutoresizingMask: NSViewMaxXMargin | NSViewMaxYMargin];

  return AUTORELEASE(aButton);
}

@end
