/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-2.0-or-later
 */

#import "MailAppearance.h"

#import "AppearanceMetrics.h"

// The smallest and the largest size a control gets, so that a caption keeps
// being smaller than the text it describes.
#define MIN_FONT_SIZE 11.0
#define MAX_FONT_SIZE 13.0

// Rows of a table with 13 point text.
#define TABLE_ROW_HEIGHT 20.0

static NSMutableSet *styledWindows = nil;


@interface MailAppearance (Private)
+ (void) _collectFontSizesInView: (NSView *) theView  into: (NSMutableArray *) theSizes;
+ (void) _scaleChildrenOfView: (NSView *) theView  by: (CGFloat) theFactor
                     restore: (NSMutableArray *) theRestore;
+ (void) _scaleView: (NSView *) theView  by: (CGFloat) theFactor
            restore: (NSMutableArray *) theRestore;
+ (NSFont *) _scaledFont: (NSFont *) theFont  by: (CGFloat) theFactor;
@end


@implementation MailAppearance

+ (BOOL) _isDecoration: (NSView *) theView
{
  // The grow box and the like belong to the theme, not to the window's own
  // content.
  return [NSStringFromClass([theView class]) hasPrefix: @"Eau"];
}


+ (void) _collectFontSizesInView: (NSView *) theView  into: (NSMutableArray *) theSizes
{
  NSEnumerator *anEnumerator;
  NSView *aView;

  if ([theView isKindOfClass: [NSControl class]] &&
      ![theView isKindOfClass: [NSScrollView class]] &&
      [(NSControl *)theView font])
    {
      [theSizes addObject: [NSNumber numberWithDouble: [[(NSControl *)theView font] pointSize]]];
    }

  if ([theView isKindOfClass: [NSBox class]])
    {
      [self _collectFontSizesInView: [(NSBox *)theView contentView]  into: theSizes];
      return;
    }

  if ([theView isKindOfClass: [NSTabView class]])
    {
      NSUInteger i;

      for (i = 0; i < [[(NSTabView *)theView tabViewItems] count]; i++)
	{
	  NSView *anItemView;

	  anItemView = [[[(NSTabView *)theView tabViewItems] objectAtIndex: i] view];
	  [self _collectFontSizesInView: anItemView  into: theSizes];
	}
      return;
    }

  if ([theView isKindOfClass: [NSScrollView class]])
    {
      return;
    }

  anEnumerator = [[theView subviews] objectEnumerator];
  while ((aView = [anEnumerator nextObject]))
    {
      if (![self _isDecoration: aView])
	{
	  [self _collectFontSizesInView: aView  into: theSizes];
	}
    }
}


+ (CGFloat) scaleFactorForView: (NSView *) theView
{
  NSMutableArray *sizes;
  CGFloat aSize, aFactor;

  sizes = [NSMutableArray array];
  [self _collectFontSizesInView: theView  into: sizes];

  if ([sizes count] == 0)
    {
      return 1.0;
    }

  sizes = (NSMutableArray *)[sizes sortedArrayUsingSelector: @selector(compare:)];
  aSize = [[sizes objectAtIndex: [sizes count] / 2] doubleValue];
  aFactor = MAX_FONT_SIZE / aSize;

  // A window that is nearly there is left as it is: the rounding of every
  // frame would cost more than the little it gains.
  if (aFactor < 1.08)
    {
      return 1.0;
    }

  return MIN(aFactor, 1.5);
}


+ (NSFont *) _scaledFont: (NSFont *) theFont  by: (CGFloat) theFactor
{
  CGFloat aSize;
  BOOL isBold;

  aSize = floor([theFont pointSize] * theFactor + 0.5);
  aSize = MAX(MIN_FONT_SIZE, MIN(MAX_FONT_SIZE, aSize));
  isBold = [[theFont fontName] rangeOfString: @"Bold"  options: NSCaseInsensitiveSearch].location != NSNotFound;

  return isBold ? [NSFont boldSystemFontOfSize: aSize] : [NSFont systemFontOfSize: aSize];
}


+ (void) _scaleView: (NSView *) theView  by: (CGFloat) theFactor
            restore: (NSMutableArray *) theRestore
{
  NSRect aFrame;

  // Resizing a view must not move what is in it a second time.
  [theRestore addObject: [NSArray arrayWithObjects: theView, [NSNumber numberWithBool: [theView autoresizesSubviews]], nil]];
  [theView setAutoresizesSubviews: NO];

  if ([theView isKindOfClass: [NSControl class]] &&
      ![theView isKindOfClass: [NSScrollView class]] &&
      [(NSControl *)theView font])
    {
      [(NSControl *)theView setFont: [self _scaledFont: [(NSControl *)theView font]  by: theFactor]];
    }

  if ([theView isKindOfClass: [NSMatrix class]])
    {
      NSMatrix *aMatrix;
      NSSize aCellSize, aSpacing;

      aMatrix = (NSMatrix *)theView;
      aCellSize = [aMatrix cellSize];
      aSpacing = [aMatrix intercellSpacing];
      [aMatrix setCellSize: NSMakeSize(floor(aCellSize.width * theFactor + 0.5), floor(aCellSize.height * theFactor + 0.5))];
      [aMatrix setIntercellSpacing: NSMakeSize(floor(aSpacing.width * theFactor + 0.5), floor(aSpacing.height * theFactor + 0.5))];
    }
  else if ([theView isKindOfClass: [NSBox class]])
    {
      [self _scaleChildrenOfView: [(NSBox *)theView contentView]  by: theFactor  restore: theRestore];
    }
  else if ([theView isKindOfClass: [NSTabView class]])
    {
      NSUInteger i;

      for (i = 0; i < [[(NSTabView *)theView tabViewItems] count]; i++)
	{
	  [self _scaleChildrenOfView: [[[(NSTabView *)theView tabViewItems] objectAtIndex: i] view]
			      by: theFactor
			 restore: theRestore];
	}
      [(NSTabView *)theView setFont: [self _scaledFont: [(NSTabView *)theView font]  by: theFactor]];
    }
  else if ([theView isKindOfClass: [NSScrollView class]])
    {
      NSView *aDocumentView;

      aDocumentView = [(NSScrollView *)theView documentView];

      if ([aDocumentView isKindOfClass: [NSTableView class]])
	{
	  NSTableView *aTableView;
	  NSUInteger i;

	  aTableView = (NSTableView *)aDocumentView;
	  [aTableView setRowHeight: TABLE_ROW_HEIGHT];
	  [aTableView setIntercellSpacing: NSMakeSize(3, 0)];

	  for (i = 0; i < [[aTableView tableColumns] count]; i++)
	    {
	      NSTableColumn *aColumn;

	      aColumn = [[aTableView tableColumns] objectAtIndex: i];

	      if ([[aColumn dataCell] respondsToSelector: @selector(setFont:)])
		{
		  [[aColumn dataCell] setFont: [NSFont systemFontOfSize: MAX_FONT_SIZE]];
		}

	      [aColumn setWidth: floor([aColumn width] * theFactor + 0.5)];
	      [aColumn setMinWidth: floor([aColumn minWidth] * theFactor + 0.5)];
	    }
	}
    }
  else
    {
      [self _scaleChildrenOfView: theView  by: theFactor  restore: theRestore];
    }

  aFrame = [theView frame];
  [theView setFrame: NSMakeRect(floor(aFrame.origin.x * theFactor + 0.5),
				floor(aFrame.origin.y * theFactor + 0.5),
				floor(aFrame.size.width * theFactor + 0.5),
				floor(aFrame.size.height * theFactor + 0.5))];
}


+ (void) _scaleChildrenOfView: (NSView *) theView  by: (CGFloat) theFactor
                     restore: (NSMutableArray *) theRestore
{
  NSEnumerator *anEnumerator;
  NSView *aView;

  [theRestore addObject: [NSArray arrayWithObjects: theView, [NSNumber numberWithBool: [theView autoresizesSubviews]], nil]];
  [theView setAutoresizesSubviews: NO];

  anEnumerator = [[NSArray arrayWithArray: [theView subviews]] objectEnumerator];
  while ((aView = [anEnumerator nextObject]))
    {
      if (![self _isDecoration: aView])
	{
	  [self _scaleView: aView  by: theFactor  restore: theRestore];
	}
    }
}


+ (void) _windowWillClose: (NSNotification *) theNotification
{
  [styledWindows removeObject: [NSValue valueWithNonretainedObject: [theNotification object]]];
  [[NSNotificationCenter defaultCenter] removeObserver: self  name: NSWindowWillCloseNotification  object: [theNotification object]];
}


+ (void) styleWindow: (NSWindow *) theWindow
{
  NSMutableArray *restore;
  NSValue *aKey;
  NSView *aContentView;
  NSSize aSize, aMinSize;
  CGFloat aFactor;
  NSUInteger i;

  if (theWindow == nil)
    {
      return;
    }

  if (styledWindows == nil)
    {
      styledWindows = [[NSMutableSet alloc] init];
    }

  aKey = [NSValue valueWithNonretainedObject: theWindow];

  if ([styledWindows containsObject: aKey])
    {
      return;
    }

  [styledWindows addObject: aKey];

  // A window that is freed may give its address to the next one.
  [[NSNotificationCenter defaultCenter] addObserver: self
					   selector: @selector(_windowWillClose:)
					       name: NSWindowWillCloseNotification
					     object: theWindow];

  aContentView = [theWindow contentView];
  aFactor = [self scaleFactorForView: aContentView];

  if (aFactor == 1.0)
    {
      return;
    }

  restore = [NSMutableArray array];
  [self _scaleChildrenOfView: aContentView  by: aFactor  restore: restore];

  aSize = [aContentView frame].size;
  aMinSize = [theWindow contentMinSize];
  [theWindow setContentSize: NSMakeSize(floor(aSize.width * aFactor + 0.5), floor(aSize.height * aFactor + 0.5))];
  [theWindow setContentMinSize: NSMakeSize(floor(aMinSize.width * aFactor + 0.5), floor(aMinSize.height * aFactor + 0.5))];

  for (i = 0; i < [restore count]; i++)
    {
      NSArray *anEntry;

      anEntry = [restore objectAtIndex: i];
      [[anEntry objectAtIndex: 0] setAutoresizesSubviews: [[anEntry objectAtIndex: 1] boolValue]];
    }
}

@end
