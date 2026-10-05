/*
**  MailWindowController+Appearance.m
**
**  The look of the window that lists the messages of a mailbox: the actions
**  in a toolbar, the list and the message across the whole width of the
**  window, and the state of the mailbox in a status line at the bottom.
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#import "MailWindowController.h"

#import <AppKit/AppKit.h>
#import <Pantomime/CWConstants.h>

#import "AppearanceMetrics.h"
#import "Constants.h"

static NSString *const GetMailItem = @"GetMail";
static NSString *const ComposeItem = @"Compose";
static NSString *const ReplyItem = @"Reply";
static NSString *const ForwardItem = @"Forward";
static NSString *const DeleteItem = @"Delete";
static NSString *const MailboxesItem = @"Mailboxes";
static NSString *const SearchItem = @"Search";

// Height of the line at the bottom of the window that tells about the mailbox.
#define STATUS_LINE_HEIGHT METRICS_TEXT_INPUT_FIELD_HEIGHT
#define TOOLBAR_ICON_SIZE 32.0

// The icons of the buttons the window is made with, by toolbar item; they are
// the same in every window.
static NSMutableDictionary *toolbarImages = nil;

@interface MailWindowController (AppearancePrivate)
- (NSImage *) _toolbarImageForItem: (NSString *) theIdentifier;
@end


@implementation MailWindowController (Appearance)

- (void) applyAppearance
{
  NSView *aContentView;
  NSToolbar *aToolbar;
  NSEnumerator *anEnumerator;
  NSView *aView;

  aContentView = [[self window] contentView];

  //
  // The buttons that were laid out in the window now are the toolbar.  The
  // nib connects them to no outlet, so they are told apart by what they do.
  //
  if (toolbarImages == nil)
    {
      toolbarImages = [[NSMutableDictionary alloc] init];
    }

  anEnumerator = [[aContentView subviews] objectEnumerator];
  while ((aView = [anEnumerator nextObject]))
    {
      NSString *anItem;
      NSString *anAction;

      if (![aView isKindOfClass: [NSButton class]])
	{
	  continue;
	}

      anAction = ([(NSButton *)aView action] ? NSStringFromSelector([(NSButton *)aView action]) : @"");
      anItem = nil;
      if ([anAction isEqualToString: @"getNewMessages:"]) anItem = GetMailItem;
      else if ([anAction isEqualToString: @"composeMessage:"]) anItem = ComposeItem;
      else if ([anAction isEqualToString: @"deleteMessage:"]) anItem = DeleteItem;
      else if ([anAction isEqualToString: @"showMailboxManager:"]) anItem = MailboxesItem;
      else if ([anAction length] == 0 && [[(NSButton *)aView title] length] > 0) anItem = SearchItem;

      if (anItem && [(NSButton *)aView image] && ![toolbarImages objectForKey: anItem])
	{
	  [toolbarImages setObject: [(NSButton *)aView image]  forKey: anItem];
	}
      [aView setHidden: YES];
    }

  aToolbar = [[NSToolbar alloc] initWithIdentifier: @"MailWindowToolbar"];
  [aToolbar setDelegate: (id)self];
  [aToolbar setAllowsUserCustomization: NO];
  [aToolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
  if ([aToolbar respondsToSelector: @selector(setSizeMode:)])
    {
      [aToolbar setSizeMode: NSToolbarSizeModeSmall];
    }
  [[self window] setToolbar: aToolbar];
  RELEASE(aToolbar);

  [self layoutAppearance];
  [self performSelector: @selector(layoutAppearance)  withObject: nil  afterDelay: 0.0];
}


//
// Where the parts of the window go, from the size the window has now: the
// window gets its final size (toolbar, saved frame) after its nib is loaded,
// and at every resize this is done again.
//
- (void) layoutAppearance
{
  NSRect aBounds;
  CGFloat aStatusHeight;

  if ([[self window] toolbar] == nil)
    {
      return;                       // the look has not been applied yet
    }

  aBounds = [[[self window] contentView] bounds];
  aStatusHeight = STATUS_LINE_HEIGHT;

  [splitView setFrame: NSMakeRect(0, aStatusHeight, NSWidth(aBounds), NSHeight(aBounds) - aStatusHeight)];
  [splitView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

  [label setFrame: NSMakeRect(METRICS_SPACE_8,
			      (aStatusHeight - 16.0) / 2.0,
			      NSWidth(aBounds) - 2 * METRICS_SPACE_8 - 16.0 - METRICS_SPACE_8,
			      16.0)];
  [label setFont: METRICS_FONT_SYSTEM_REGULAR_11];
  [label setTextColor: [NSColor disabledControlTextColor]];
  [label setAlignment: NSLeftTextAlignment];
  [label setBezeled: NO];
  [label setDrawsBackground: NO];
  [label setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin];

  [progressIndicator setFrame: NSMakeRect(NSWidth(aBounds) - 16.0 - METRICS_SPACE_8,
					  (aStatusHeight - 16.0) / 2.0,
					  16.0, 16.0)];
  [progressIndicator setAutoresizingMask: NSViewMinXMargin | NSViewMaxYMargin];

  [self _sizeSubjectColumn];
}


//
// The subject takes the width that the other columns leave, so that the list
// is as wide as the window.
//
- (void) _sizeSubjectColumn
{
  NSArray *allColumns;
  CGFloat anAvailableWidth, anOtherWidth;
  NSUInteger i;

  allColumns = [dataView tableColumns];

  if (![allColumns containsObject: subjectColumn])
    {
      return;
    }

  anAvailableWidth = [[dataView enclosingScrollView] contentSize].width;
  anOtherWidth = 0;

  for (i = 0; i < [allColumns count]; i++)
    {
      NSTableColumn *aColumn;

      aColumn = [allColumns objectAtIndex: i];

      if (aColumn != subjectColumn)
	{
	  anOtherWidth += [aColumn width];
	}
    }

  anOtherWidth += [dataView intercellSpacing].width * [allColumns count];
  [subjectColumn setWidth: MAX([subjectColumn minWidth], anAvailableWidth - anOtherWidth)];
}


#pragma mark - Toolbar

- (NSImage *) _toolbarImageForItem: (NSString *) theIdentifier
{
  NSImage *anImage;

  anImage = [toolbarImages objectForKey: theIdentifier];
  if (anImage == nil)
    {
      anImage = [NSImage imageNamed: ([theIdentifier isEqualToString: ReplyItem] ? @"reply_32" : @"forward_32")];
    }
  anImage = AUTORELEASE([anImage copy]);
  [anImage setSize: NSMakeSize(TOOLBAR_ICON_SIZE, TOOLBAR_ICON_SIZE)];
  return anImage;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) theToolbar
{
  return [NSArray arrayWithObjects: GetMailItem, ComposeItem, NSToolbarSeparatorItemIdentifier,
		  ReplyItem, ForwardItem, DeleteItem, NSToolbarSeparatorItemIdentifier,
		  MailboxesItem, NSToolbarFlexibleSpaceItemIdentifier, SearchItem, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) theToolbar
{
  return [self toolbarDefaultItemIdentifiers: theToolbar];
}

- (NSToolbarItem *) toolbar: (NSToolbar *) theToolbar
      itemForItemIdentifier: (NSString *) theIdentifier
  willBeInsertedIntoToolbar: (BOOL) theFlag
{
  NSToolbarItem *anItem;
  NSString *aLabel;
  id aTarget;           // nil: whoever in the responder chain answers
  SEL anAction;
  NSInteger aTag;

  aTarget = nil;
  aTag = 0;

  if ([theIdentifier isEqualToString: GetMailItem])
    {
      aLabel = _(@"Get Mail");
      anAction = @selector(getNewMessages:);
    }
  else if ([theIdentifier isEqualToString: ComposeItem])
    {
      aLabel = _(@"Compose");
      anAction = @selector(composeMessage:);
    }
  else if ([theIdentifier isEqualToString: ReplyItem])
    {
      aLabel = _(@"Reply");
      aTarget = self;
      anAction = @selector(replyToMessage:);
      aTag = PantomimeNormalReplyMode;
    }
  else if ([theIdentifier isEqualToString: ForwardItem])
    {
      aLabel = _(@"Forward");
      aTarget = self;
      anAction = @selector(forwardMessage:);
      aTag = PantomimeAttachmentForwardMode;
    }
  else if ([theIdentifier isEqualToString: DeleteItem])
    {
      aLabel = _(@"Delete");
      anAction = @selector(deleteMessage:);
    }
  else if ([theIdentifier isEqualToString: MailboxesItem])
    {
      aLabel = _(@"Mailboxes");
      anAction = @selector(showMailboxManager:);
    }
  else if ([theIdentifier isEqualToString: SearchItem])
    {
      aLabel = _(@"Search");
      aTarget = [NSApp delegate];
      anAction = @selector(showFindWindow:);
    }
  else
    {
      return nil;
    }

  anItem = AUTORELEASE([[NSToolbarItem alloc] initWithItemIdentifier: theIdentifier]);
  [anItem setLabel: aLabel];
  [anItem setPaletteLabel: aLabel];
  [anItem setToolTip: aLabel];
  [anItem setTag: aTag];
  [anItem setTarget: aTarget];
  [anItem setAction: anAction];
  [anItem setImage: [self _toolbarImageForItem: theIdentifier]];
  return anItem;
}

//
// The toolbar item asks this window, which is the one that knows whether a
// message is selected, and the application does the work.
//
- (void) forwardMessage: (id) sender
{
  [(id)[NSApp delegate] forwardMessage: sender];
}

//
// What needs a message to work on is dimmed until one is selected.
//
- (BOOL) validateToolbarItem: (NSToolbarItem *) theItem
{
  NSString *anIdentifier = [theItem itemIdentifier];

  if ([anIdentifier isEqualToString: ReplyItem] ||
      [anIdentifier isEqualToString: ForwardItem] ||
      [anIdentifier isEqualToString: DeleteItem])
    {
      return ([dataView numberOfSelectedRows] > 0);
    }

  return YES;
}

@end
