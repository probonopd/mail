/*
**  EditWindowController+Appearance.m
**
**  The look of the window in which a message is written: the actions in a
**  toolbar, the addresses and the subject in rows under it, and the size of
**  the message in a status line at the bottom.
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#import "EditWindowController.h"

#import <AppKit/AppKit.h>

#import "AppearanceMetrics.h"

static NSString *const SendItem = @"Send";
static NSString *const AttachItem = @"Attach";
static NSString *const AddressesItem = @"Addresses";
static NSString *const DraftItem = @"Draft";

#define TOOLBAR_ICON_SIZE 32.0

// The width of the column of captions in front of the fields.
#define CAPTION_WIDTH 60.0
#define STATUS_LINE_HEIGHT METRICS_TEXT_INPUT_FIELD_HEIGHT

// The buttons that were in the window, by what they do: the nib connects some
// of them to no outlet.  The toolbar items call the same targets and actions.
static NSMutableDictionary *toolbarButtons = nil;


@implementation EditWindowController (Appearance)

- (void) applyAppearance
{
  NSToolbar *aToolbar;
  NSView *aContentView;
  NSEnumerator *anEnumerator;
  NSView *aView;
  NSArray *allSubviews;

  aContentView = [[self window] contentView];

  toolbarButtons = [[NSMutableDictionary alloc] init];

  // The four big buttons at the top become the toolbar; the buttons that
  // show the Cc and Bcc rows stay with the rows.
  allSubviews = [NSArray arrayWithArray: [aContentView subviews]];
  anEnumerator = [allSubviews objectEnumerator];

  while ((aView = [anEnumerator nextObject]))
    {
      NSString *anIdentifier;

      if (![aView isKindOfClass: [NSButton class]] || ![[aView className] isEqualToString: @"ImageButton"])
	{
	  continue;
	}

      anIdentifier = [self _toolbarIdentifierForButton: (NSButton *)aView];

      if (anIdentifier)
	{
	  [toolbarButtons setObject: aView  forKey: anIdentifier];
	  [aView setHidden: YES];
	}
    }

  aToolbar = [[NSToolbar alloc] initWithIdentifier: @"EditWindowToolbar"];
  [aToolbar setDelegate: self];
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
// A button is told from the others by its title, as the nib does not give it
// any other name.
//
- (NSString *) _toolbarIdentifierForButton: (NSButton *) theButton
{
  NSString *aTitle;

  aTitle = [[theButton title] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];

  if ([aTitle isEqualToString: @"Send"])
    {
      return SendItem;
    }
  if ([aTitle isEqualToString: @"Attach"])
    {
      return AttachItem;
    }
  if ([aTitle isEqualToString: @"Adress"] || [aTitle isEqualToString: @"Address"])
    {
      return AddressesItem;
    }
  if ([aTitle isEqualToString: @"Save"])
    {
      return DraftItem;
    }

  return nil;
}


//
// Where the parts of the window go, from the size it has now; done again at
// every resize and whenever the Cc or Bcc row is shown or hidden.
//
- (void) layoutAppearance
{
  NSRect aBounds;
  NSArray *someRows;
  NSView *aContentView;
  CGFloat y, aFieldX, aFieldWidth, aRowHeight;
  NSUInteger i;

  if ([[self window] toolbar] == nil)
    {
      return;
    }

  aContentView = [[self window] contentView];
  aBounds = [aContentView bounds];
  aRowHeight = METRICS_TEXT_INPUT_FIELD_HEIGHT;
  aFieldX = METRICS_SPACE_12 + CAPTION_WIDTH + METRICS_SPACE_8;
  aFieldWidth = NSWidth(aBounds) - aFieldX - METRICS_SPACE_12;

  y = NSHeight(aBounds) - METRICS_SPACE_8 - aRowHeight;

  // From, with the buttons that show the Cc and Bcc rows at its right end.
  [self _placeCaption: [self _captionLabelNamed: @"From:"]  field: accountPopUpButton  y: y
	 fieldX: aFieldX  fieldWidth: 0  height: aRowHeight];
  [self _placeCopyButtonsAtY: y  rowHeight: aRowHeight  width: NSWidth(aBounds)];
  y -= aRowHeight + METRICS_SPACE_8;

  someRows = [NSArray arrayWithObjects:
    [NSArray arrayWithObjects: toLabel, toText, nil],
    [NSArray arrayWithObjects: ccLabel, ccText, nil],
    [NSArray arrayWithObjects: bccLabel, bccText, nil],
    [NSArray arrayWithObjects: subjectLabel, subjectText, nil],
    nil];

  for (i = 0; i < [someRows count]; i++)
    {
      NSTextField *aLabel, *aField;

      aLabel = [[someRows objectAtIndex: i] objectAtIndex: 0];
      aField = [[someRows objectAtIndex: i] objectAtIndex: 1];

      if ([aField isHidden])
	{
	  continue;
	}

      [aLabel setFont: METRICS_FONT_SYSTEM_REGULAR_13];
      [aLabel setTextColor: [NSColor disabledControlTextColor]];
      [aLabel setAlignment: NSRightTextAlignment];
      [aLabel setFrame: NSMakeRect(METRICS_SPACE_12, y + 2, CAPTION_WIDTH, 17)];
      [aLabel setAutoresizingMask: NSViewMinYMargin];

      [aField setFont: METRICS_FONT_SYSTEM_REGULAR_13];
      [aField setFrame: NSMakeRect(aFieldX, y, aFieldWidth, aRowHeight)];
      [aField setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

      y -= aRowHeight + METRICS_SPACE_8;
    }

  // The line between the headers and the text, the text, the status line.
  [self _placeSeparatorAtY: y + aRowHeight  width: NSWidth(aBounds)];

  [sizeLabel setFont: METRICS_FONT_SYSTEM_REGULAR_11];
  [sizeLabel setTextColor: [NSColor disabledControlTextColor]];
  [sizeLabel setAlignment: NSLeftTextAlignment];
  [sizeLabel setFrame: NSMakeRect(METRICS_SPACE_8, 2, NSWidth(aBounds) - 2 * METRICS_SPACE_8, 16)];
  [sizeLabel setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin];
  [sizeLabel setHidden: NO];

  [scrollView setFrame: NSMakeRect(0, STATUS_LINE_HEIGHT, NSWidth(aBounds), MAX(40, y + aRowHeight - STATUS_LINE_HEIGHT))];
  [scrollView setBorderType: NSNoBorder];
  [scrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
}


- (NSTextField *) _captionLabelNamed: (NSString *) theName
{
  // The caption in front of the From pop up is the one the nib made.
  NSEnumerator *anEnumerator;
  NSView *aView;

  anEnumerator = [[[[self window] contentView] subviews] objectEnumerator];

  while ((aView = [anEnumerator nextObject]))
    {
      if ([aView isKindOfClass: [NSTextField class]] &&
	  [[(NSTextField *)aView stringValue] isEqualToString: _(theName)])
	{
	  return (NSTextField *)aView;
	}
    }

  return nil;
}


- (void) _placeCaption: (NSTextField *) theLabel
		 field: (NSView *) theField
		     y: (CGFloat) theY
		fieldX: (CGFloat) theFieldX
	    fieldWidth: (CGFloat) theFieldWidth
		height: (CGFloat) theHeight
{
  [theLabel setFont: METRICS_FONT_SYSTEM_REGULAR_13];
  [theLabel setTextColor: [NSColor disabledControlTextColor]];
  [theLabel setAlignment: NSRightTextAlignment];
  [theLabel setFrame: NSMakeRect(METRICS_SPACE_12, theY + 2, CAPTION_WIDTH, 17)];
  [theLabel setAutoresizingMask: NSViewMinYMargin];

  [theField setFrame: NSMakeRect(theFieldX, theY, MAX(NSWidth([theField frame]), 200), theHeight)];
  [theField setAutoresizingMask: NSViewMinYMargin];
}


- (void) _placeCopyButtonsAtY: (CGFloat) theY
		    rowHeight: (CGFloat) theRowHeight
			width: (CGFloat) theWidth
{
  NSEnumerator *anEnumerator;
  NSView *aView;
  NSMutableDictionary *someButtons;
  NSString *aTitle;
  CGFloat x;

  // The nib has them as CC and BCC.
  someButtons = [NSMutableDictionary dictionary];
  anEnumerator = [[[[self window] contentView] subviews] objectEnumerator];

  while ((aView = [anEnumerator nextObject]))
    {
      if ([aView isKindOfClass: [NSButton class]] && ![aView isHidden])
	{
	  [someButtons setObject: aView  forKey: [(NSButton *)aView title]];
	}
    }

  x = theWidth - METRICS_SPACE_12;
  anEnumerator = [[NSArray arrayWithObjects: @"BCC", @"CC", nil] objectEnumerator];

  while ((aTitle = [anEnumerator nextObject]))
    {
      NSButton *aButton;
      NSRect aFrame;

      aButton = [someButtons objectForKey: aTitle];

      if (aButton == nil)
	{
	  continue;
	}

      aFrame = NSMakeRect(0, theY + (theRowHeight - METRICS_BUTTON_HEIGHT) / 2, [aTitle length] * 11 + 22, METRICS_BUTTON_HEIGHT);
      aFrame.origin.x = x - NSWidth(aFrame);
      [aButton setFrame: aFrame];
      [aButton setAutoresizingMask: NSViewMinXMargin | NSViewMinYMargin];
      [aButton setFont: METRICS_FONT_SYSTEM_REGULAR_11];
      x = NSMinX(aFrame) - METRICS_SPACE_8;
    }
}


- (void) _placeSeparatorAtY: (CGFloat) theY  width: (CGFloat) theWidth
{
  NSEnumerator *anEnumerator;
  NSView *aView;

  anEnumerator = [[[[self window] contentView] subviews] objectEnumerator];

  while ((aView = [anEnumerator nextObject]))
    {
      if ([aView isKindOfClass: [NSBox class]])
	{
	  [aView setFrame: NSMakeRect(0, theY, theWidth, 2)];
	  [aView setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
	  return;
	}
    }
}


#pragma mark - Toolbar

- (NSImage *) _toolbarImageForItem: (NSString *) theIdentifier
{
  NSDictionary *someNames;
  NSImage *anImage;

  someNames = [NSDictionary dictionaryWithObjectsAndKeys:
		 @"send_32", SendItem,
		 @"attach_32", AttachItem,
		 @"addresses_32", AddressesItem,
		 @"drafts_32", DraftItem,
		 nil];

  anImage = [[NSImage imageNamed: [someNames objectForKey: theIdentifier]] copy];
  [anImage setSize: NSMakeSize(TOOLBAR_ICON_SIZE, TOOLBAR_ICON_SIZE)];

  return AUTORELEASE(anImage);
}


- (NSToolbarItem *) toolbar: (NSToolbar *) theToolbar
      itemForItemIdentifier: (NSString *) theIdentifier
  willBeInsertedIntoToolbar: (BOOL) theFlag
{
  NSToolbarItem *anItem;
  NSButton *aButton;
  NSString *aLabel;

  aButton = [toolbarButtons objectForKey: theIdentifier];

  if (aButton == nil)
    {
      return nil;
    }

  if ([theIdentifier isEqualToString: SendItem])
    {
      aLabel = _(@"Send");
    }
  else if ([theIdentifier isEqualToString: AttachItem])
    {
      aLabel = _(@"Attach");
    }
  else if ([theIdentifier isEqualToString: AddressesItem])
    {
      aLabel = _(@"Addresses");
    }
  else
    {
      aLabel = _(@"Save as Draft");
    }

  anItem = [[NSToolbarItem alloc] initWithItemIdentifier: theIdentifier];
  [anItem setLabel: aLabel];
  [anItem setPaletteLabel: aLabel];
  [anItem setImage: [self _toolbarImageForItem: theIdentifier]];
  [anItem setTarget: [aButton target]];
  [anItem setAction: [aButton action]];

  return AUTORELEASE(anItem);
}


- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) theToolbar
{
  return [NSArray arrayWithObjects: SendItem, NSToolbarSeparatorItemIdentifier,
		  AttachItem, AddressesItem, NSToolbarFlexibleSpaceItemIdentifier, DraftItem, nil];
}


- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) theToolbar
{
  return [self toolbarDefaultItemIdentifiers: theToolbar];
}

@end
