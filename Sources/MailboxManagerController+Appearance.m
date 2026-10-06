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
#import "GNUMail.h"
#import "MailWindowController.h"

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


#pragma mark - Drawer

// The list of mailboxes is one for the whole application, so there is one
// drawer; it hangs on the left side of the message window that was used last
// and moves to another one when that is asked for.
static NSDrawer *mailboxesDrawer = nil;

#define DRAWER_WIDTH 220.0
#define DRAWER_MIN_WIDTH 140.0
#define DRAWER_MAX_WIDTH 400.0

- (NSWindow *) _parentWindowForDrawer
{
  NSWindow *aWindow;

  aWindow = [GNUMail lastMailWindowOnTop];

  // A window that shows a single message has no room for the list: the list
  // goes to the window of a mailbox.
  if (aWindow == nil || ![[aWindow windowController] isKindOfClass: [MailWindowController class]])
    {
      NSArray *allWindows;
      NSInteger i;

      allWindows = [GNUMail allMailWindows];
      aWindow = nil;

      for (i = [allWindows count] - 1; i >= 0; i--)
	{
	  if ([[[allWindows objectAtIndex: i] windowController] isKindOfClass: [MailWindowController class]])
	    {
	      aWindow = [allWindows objectAtIndex: i];
	      break;
	    }
	}
    }

  return aWindow;
}


- (void) _listSizeChanged: (NSNotification *) theNotification
{
  [outlineView sizeLastColumnToFit];
}


- (void) toggleDrawer
{
  NSWindow *aParentWindow;

  aParentWindow = [self _parentWindowForDrawer];

  if (aParentWindow == nil)
    {
      // No window of a mailbox to hang it on.
      NSBeep();
      return;
    }

  if (mailboxesDrawer == nil)
    {
      NSView *aListView;

      // The list moves out of the window it was made in.
      aListView = RETAIN([[self window] contentView]);
      [[self window] setContentView: AUTORELEASE([[NSView alloc] initWithFrame: NSZeroRect])];
      [[self window] orderOut: nil];

      // The drawer is as wide as its content, which has the size of the window it came from.
      [aListView setFrameSize: NSMakeSize(DRAWER_WIDTH, 300)];

      mailboxesDrawer = [[NSDrawer alloc] initWithContentSize: NSMakeSize(DRAWER_WIDTH, 300)
						preferredEdge: NSMinXEdge];
      [mailboxesDrawer setMinContentSize: NSMakeSize(DRAWER_MIN_WIDTH, 100)];
      [mailboxesDrawer setMaxContentSize: NSMakeSize(DRAWER_MAX_WIDTH, 10000)];
      [mailboxesDrawer setContentView: aListView];
      RELEASE(aListView);

      // The name takes the width that the counts leave.
      [[NSNotificationCenter defaultCenter] addObserver: self
					       selector: @selector(_listSizeChanged:)
						   name: NSViewFrameDidChangeNotification
						 object: [outlineView enclosingScrollView]];
      [[outlineView enclosingScrollView] setPostsFrameChangedNotifications: YES];
    }

  if ([mailboxesDrawer parentWindow] != aParentWindow)
    {
      BOOL wasOpen;

      wasOpen = ([mailboxesDrawer state] == NSDrawerOpenState || [mailboxesDrawer state] == NSDrawerOpeningState);
      [mailboxesDrawer close];
      [mailboxesDrawer setParentWindow: aParentWindow];

      if (wasOpen)
	{
	  [mailboxesDrawer open];
	  return;
	}
    }

  if ([mailboxesDrawer state] != NSDrawerOpenState && [mailboxesDrawer state] != NSDrawerOpeningState)
    {
      [self _makeRoomOnTheLeftOfWindow: aParentWindow];
    }

  [mailboxesDrawer toggle: self];
}


// A drawer opens on the side of the window where there is room for it, and on
// the left only when there is: a window that is near the left edge of the
// screen is moved to the right by what is missing, so that the list comes out
// on the left, as it always does.
- (void) _makeRoomOnTheLeftOfWindow: (NSWindow *) theWindow
{
  NSRect aWindowFrame, aScreenFrame;
  CGFloat aNeeded, aMissing, aRoomOnTheRight;

  aWindowFrame = [theWindow frame];
  aScreenFrame = [[theWindow screen] visibleFrame];
  aNeeded = ceil(DRAWER_WIDTH * [theWindow userSpaceScaleFactor]) + METRICS_SPACE_8;
  aMissing = aNeeded - (NSMinX(aWindowFrame) - NSMinX(aScreenFrame));

  if (aMissing <= 0)
    {
      return;
    }

  aRoomOnTheRight = NSMaxX(aScreenFrame) - NSMaxX(aWindowFrame);

  if (aMissing > aRoomOnTheRight)
    {
      // Not enough room to move it: the window gets narrower.
      aWindowFrame.size.width -= (aMissing - aRoomOnTheRight);
      aMissing = aRoomOnTheRight;
    }

  aWindowFrame.origin.x += aMissing;
  [theWindow setFrame: aWindowFrame  display: YES];
}

@end
