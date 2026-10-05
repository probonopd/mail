/*
**  AboutPanelController.m
**
**  Copyright (c) 2002-2005 Ludovic Marcotte
**  Copyright (c) 2017      Riccardo Mottola
**
**  Author: Ludovic Marcotte <ludovic@Sophos.ca>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "AppearanceMetrics.h"
#import "MailAppearance.h"
#import "AboutPanelController.h"

#import "Utilities.h"
#import "Constants.h"

static AboutPanelController *singleInstance = nil;

//
//
//
// The size of the panel and of the icon at its top.
#define ABOUT_WIDTH 360.0
#define ABOUT_HEIGHT 330.0
#define ABOUT_ICON_SIZE 64.0

@implementation AboutPanelController

- (id) initWithWindowNibName: (NSString *) windowNibName
{ 
  self = [super initWithWindowNibName: windowNibName];

  [[self window] setTitle: _(@"About GNUMail")];
  
  // We finally set our autosave window frame name and restore the one from the user's defaults.
  [[self window] setFrameAutosaveName: @"AboutPanel"];
  [[self window] setFrameUsingName: @"AboutPanel"];
 
  return self;
}


//
//
//
- (void) dealloc
{
  NSDebugLog(@"AboutPanelController: -dealloc");
  singleInstance = nil;
  [super dealloc];
}


//
// action methods
//


//
// delegate methods
//
- (void) windowWillClose: (NSNotification *) theNotification
{
  AUTORELEASE(self);
}

//
//
//
- (void) windowDidLoad
{
  [self _buildContent];
}


//
// The panel is laid out in code: the application icon and name, the version,
// the people who made the program in a list that scrolls, and the copyright.
//
- (NSTextField *) _labelWithString: (NSString *) theString
			      font: (NSFont *) theFont
			     color: (NSColor *) theColor
			     frame: (NSRect) theFrame
{
  NSTextField *aLabel;

  aLabel = [[NSTextField alloc] initWithFrame: theFrame];
  [aLabel setStringValue: theString];
  [aLabel setFont: theFont];
  [aLabel setTextColor: theColor];
  [aLabel setAlignment: NSCenterTextAlignment];
  [aLabel setBezeled: NO];
  [aLabel setDrawsBackground: NO];
  [aLabel setEditable: NO];
  [aLabel setSelectable: NO];
  [aLabel setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

  return AUTORELEASE(aLabel);
}


- (void) _buildContent
{
  NSMutableAttributedString *someCredits;
  NSScrollView *aScrollView;
  NSTextView *aTextView;
  NSView *aContentView;
  NSImageView *anImageView;
  NSDictionary *aHeadingAttributes, *aBodyAttributes;
  NSArray *someSections;
  NSEnumerator *anEnumerator;
  NSArray *aSection;
  NSRect aBounds;
  CGFloat aWidth, y;
  NSUInteger i;

  [(NSPanel *)[self window] setFloatingPanel: NO];
  [[self window] setContentSize: NSMakeSize(ABOUT_WIDTH, ABOUT_HEIGHT)];

  aContentView = [[self window] contentView];
  aBounds = [aContentView bounds];
  aWidth = NSWidth(aBounds);

  // The nib's controls are replaced.
  while ([[aContentView subviews] count] > 0)
    {
      [[[aContentView subviews] lastObject] removeFromSuperview];
    }

  y = NSHeight(aBounds) - METRICS_SPACE_20 - ABOUT_ICON_SIZE;

  anImageView = [[NSImageView alloc] initWithFrame: NSMakeRect((aWidth - ABOUT_ICON_SIZE) / 2, y, ABOUT_ICON_SIZE, ABOUT_ICON_SIZE)];
  [anImageView setImage: [NSApp applicationIconImage]];
  [anImageView setImageScaling: NSImageScaleProportionallyUpOrDown];
  [anImageView setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin];
  [aContentView addSubview: anImageView];
  RELEASE(anImageView);

  y -= METRICS_SPACE_8 + 20;
  [aContentView addSubview: [self _labelWithString: @"GNUMail"
					      font: [NSFont boldSystemFontOfSize: 16]
					     color: [NSColor controlTextColor]
					     frame: NSMakeRect(0, y, aWidth, 20)]];

  y -= 16;
  [aContentView addSubview: [self _labelWithString: [NSString stringWithFormat: _(@"Version %@"), GNUMailVersion()]
					      font: METRICS_FONT_SYSTEM_REGULAR_11
					     color: [NSColor disabledControlTextColor]
					     frame: NSMakeRect(0, y, aWidth, 14)]];

  // The copyright at the bottom, the credits between.
  y = METRICS_SPACE_12;
  [aContentView addSubview: [self _labelWithString: GNUMailCopyrightInfo()
					      font: METRICS_FONT_SYSTEM_REGULAR_11
					     color: [NSColor disabledControlTextColor]
					     frame: NSMakeRect(METRICS_SPACE_12, y, aWidth - 2 * METRICS_SPACE_12, 28)]];
  [[[aContentView subviews] lastObject] setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin];

  aHeadingAttributes = [NSDictionary dictionaryWithObjectsAndKeys: METRICS_FONT_SYSTEM_BOLD_11, NSFontAttributeName, nil];
  aBodyAttributes = [NSDictionary dictionaryWithObjectsAndKeys: METRICS_FONT_SYSTEM_REGULAR_11, NSFontAttributeName, nil];

  someSections = [NSArray arrayWithObjects:
    [NSArray arrayWithObjects: _(@"Main author"), @"Ludovic Marcotte", nil],
    [NSArray arrayWithObjects: _(@"Contributors"),
       @"Ken Ferry, Francis Lachapelle, Bjorn Giesler, Jonathan B. Leffert, Riccardo Mottola, Pierre-Yves Rivaille, Nicolas Roard, Ujwal S. Setlur", nil],
    [NSArray arrayWithObjects: _(@"Special thanks"),
       @"Matt Ackeret, Luis Garcia Alanis, Martin Brecher, Erik Dalen, Andrew Lindesay, Jeff Meininger, Stephane Peron, Jeff Teunissen", nil],
    nil];

  someCredits = [[NSMutableAttributedString alloc] init];
  anEnumerator = [someSections objectEnumerator];
  i = 0;

  while ((aSection = [anEnumerator nextObject]))
    {
      NSString *aHeading, *aBody;

      aHeading = [NSString stringWithFormat: @"%@%@\n", (i > 0 ? @"\n" : @""), [aSection objectAtIndex: 0]];
      aBody = [NSString stringWithFormat: @"%@\n", [aSection objectAtIndex: 1]];
      [someCredits appendAttributedString: [[[NSAttributedString alloc] initWithString: aHeading  attributes: aHeadingAttributes] autorelease]];
      [someCredits appendAttributedString: [[[NSAttributedString alloc] initWithString: aBody  attributes: aBodyAttributes] autorelease]];
      i++;
    }

  aScrollView = [[NSScrollView alloc] initWithFrame: NSMakeRect(METRICS_SPACE_20, y + 28 + METRICS_SPACE_12,
								 aWidth - 2 * METRICS_SPACE_20,
								 NSHeight(aBounds) - (y + 28 + METRICS_SPACE_12) - (METRICS_SPACE_20 + ABOUT_ICON_SIZE + METRICS_SPACE_8 + 20 + 16 + METRICS_SPACE_12))];
  [aScrollView setHasVerticalScroller: YES];
  [aScrollView setBorderType: NSBezelBorder];
  [aScrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

  aTextView = [[NSTextView alloc] initWithFrame: [[aScrollView contentView] bounds]];
  [aTextView setEditable: NO];
  [aTextView setSelectable: YES];
  [aTextView setHorizontallyResizable: NO];
  [aTextView setVerticallyResizable: YES];
  [aTextView setAutoresizingMask: NSViewWidthSizable];
  [[aTextView textStorage] setAttributedString: someCredits];
  [aScrollView setDocumentView: aTextView];
  [aContentView addSubview: aScrollView];

  RELEASE(aTextView);
  RELEASE(aScrollView);
  RELEASE(someCredits);
}


//
// class methods
//
+ (id) singleInstance
{
  if ( !singleInstance )
    {
      singleInstance = [[AboutPanelController alloc] initWithWindowNibName: @"AboutPanel"];
    }

  return singleInstance;
}

@end
