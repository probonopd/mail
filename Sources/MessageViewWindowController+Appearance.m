/*
**  MessageViewWindowController+Appearance.m
**
**  The look of the window in which one message is read: the actions in a
**  toolbar and the message across the whole window under it.
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#import "MessageViewWindowController.h"

#import <AppKit/AppKit.h>

#import "AppearanceMetrics.h"

static NSString *const PreviousItem = @"Previous";
static NSString *const NextItem = @"Next";
static NSString *const ReplyItem = @"Reply";
static NSString *const ForwardItem = @"Forward";
static NSString *const DeleteItem = @"Delete";
static NSString *const HeadersItem = @"Headers";

#define TOOLBAR_ICON_SIZE 32.0

// The buttons that were in the window, by toolbar item; the toolbar items
// call the same targets and actions.
static NSMutableDictionary *toolbarButtons = nil;


@implementation MessageViewWindowController (Appearance)

- (void) applyAppearance
{
  NSToolbar *aToolbar;
  NSView *aContentView;
  NSDictionary *someTitles;
  NSEnumerator *anEnumerator;
  NSView *aView;
  NSRect aBounds;

  aContentView = [[self window] contentView];
  aBounds = [aContentView bounds];

  someTitles = [NSDictionary dictionaryWithObjectsAndKeys:
		  PreviousItem, @"Up",
		  NextItem, @"Down",
		  ReplyItem, @"Reply",
		  ForwardItem, @"Forward",
		  DeleteItem, @"Delete",
		  HeadersItem, @"Header",
		  nil];

  if (toolbarButtons == nil)
    {
      toolbarButtons = [[NSMutableDictionary alloc] init];
    }

  anEnumerator = [[NSArray arrayWithArray: [aContentView subviews]] objectEnumerator];

  while ((aView = [anEnumerator nextObject]))
    {
      NSString *anIdentifier;

      if (![aView isKindOfClass: [NSButton class]])
	{
	  continue;
	}

      anIdentifier = [someTitles objectForKey: [[(NSButton *)aView title] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]];

      if (anIdentifier)
	{
	  [toolbarButtons setObject: [NSDictionary dictionaryWithObjectsAndKeys:
					[(NSButton *)aView target] ? [(NSButton *)aView target] : (id)[NSNull null], @"target",
					NSStringFromSelector([(NSButton *)aView action]), @"action",
					nil]
			     forKey: anIdentifier];
	  [aView removeFromSuperview];
	}
    }

  // The message fills the window under the toolbar.
  [textView setMinSize: NSMakeSize(0, 0)];
  [[textView enclosingScrollView] setFrame: aBounds];
  [[textView enclosingScrollView] setBorderType: NSNoBorder];
  [[textView enclosingScrollView] setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

  aToolbar = [[NSToolbar alloc] initWithIdentifier: @"MessageViewWindowToolbar"];
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
// The window gets its final size, with the toolbar, after its nib is loaded.
//
- (void) layoutAppearance
{
  NSView *aContentView;

  if ([[self window] toolbar] == nil)
    {
      return;
    }

  aContentView = [[self window] contentView];
  [[textView enclosingScrollView] setFrame: [aContentView bounds]];
}


#pragma mark - Toolbar

- (NSImage *) _toolbarImageForItem: (NSString *) theIdentifier
{
  NSDictionary *someNames;
  NSImage *anImage;

  someNames = [NSDictionary dictionaryWithObjectsAndKeys:
		 @"up_15", PreviousItem,
		 @"down_15", NextItem,
		 @"reply_32", ReplyItem,
		 @"forward_32", ForwardItem,
		 @"delete_32", DeleteItem,
		 @"show_all_headers_32", HeadersItem,
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
  NSDictionary *anEntry;
  NSString *aLabel;
  id aTarget;

  anEntry = [toolbarButtons objectForKey: theIdentifier];

  if (anEntry == nil)
    {
      return nil;
    }

  if ([theIdentifier isEqualToString: PreviousItem])
    {
      aLabel = _(@"Previous");
    }
  else if ([theIdentifier isEqualToString: NextItem])
    {
      aLabel = _(@"Next");
    }
  else if ([theIdentifier isEqualToString: ReplyItem])
    {
      aLabel = _(@"Reply");
    }
  else if ([theIdentifier isEqualToString: ForwardItem])
    {
      aLabel = _(@"Forward");
    }
  else if ([theIdentifier isEqualToString: DeleteItem])
    {
      aLabel = _(@"Delete");
    }
  else
    {
      aLabel = _(@"Headers");
    }

  aTarget = [anEntry objectForKey: @"target"];

  anItem = [[NSToolbarItem alloc] initWithItemIdentifier: theIdentifier];
  [anItem setLabel: aLabel];
  [anItem setPaletteLabel: aLabel];
  [anItem setImage: [self _toolbarImageForItem: theIdentifier]];
  [anItem setTarget: (aTarget == (id)[NSNull null] ? nil : aTarget)];
  [anItem setAction: NSSelectorFromString([anEntry objectForKey: @"action"])];

  return AUTORELEASE(anItem);
}


- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) theToolbar
{
  return [NSArray arrayWithObjects: PreviousItem, NextItem, NSToolbarSeparatorItemIdentifier,
		  ReplyItem, ForwardItem, DeleteItem, NSToolbarFlexibleSpaceItemIdentifier, HeadersItem, nil];
}


- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) theToolbar
{
  return [self toolbarDefaultItemIdentifiers: theToolbar];
}

@end
