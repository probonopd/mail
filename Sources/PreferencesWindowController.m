/*
**  PreferencesWindowController.m
**
**  Copyright (c) 2001-2007 Ludovic Marcotte
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
** You should have received a copy of the GNU General Public License
** along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "AppearanceMetrics.h"
#import "MailAppearance.h"
#import "PreferencesWindowController.h"

#import "ConsoleWindowController.h"
#import "Constants.h"
#import "GNUMail.h"
#import "MailWindowController.h"
#import "NSBundle+Extensions.h"
#import "NSUserDefaults+Extensions.h"

#import "GNUMailBundle.h"

static PreferencesWindowController *singleInstance = nil;


//
// Private interface
//
@interface PreferencesWindowController (Private)
- (void) _initializeModuleWithName: (NSString *) theName
                           atIndex: (int) theIndex;
- (void) _releaseLoadedBundles;
- (void) _selectCellWithTitle: (NSString *) theTitle;
@end

//
//
//
#define PREFERENCES_ICON_WIDTH 72.0
#define PREFERENCES_ICON_HEIGHT 62.0

@implementation PreferencesWindowController

- (id) initWithWindowNibName: (NSString *) windowNibName
{
  NSDictionary *allPreferences;

  self = [super initWithWindowNibName: windowNibName];

  // We copy the current preferences to a volatile domain
  allPreferences = [NSDictionary dictionaryWithDictionary: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
 
  // FIXME - This cause a segfault on OS X when reloading a 2nd time the preferences panel
  [[NSUserDefaults standardUserDefaults] removeVolatileDomainForName: @"PREFERENCES"];
  [[NSUserDefaults standardUserDefaults] setVolatileDomain: allPreferences  forName: @"PREFERENCES"];

  // We set our window title
  [[self window] setTitle: _(@"Preferences Panel")];

  // We set our mode
  [self setMode: [[NSUserDefaults standardUserDefaults] integerForKey: @"PREFERENCES_MODE"  default: MODE_STANDARD]];

  // We initialize our matrix with the standard modules
  [self initializeWithStandardModules];

  // We then add our additional modules
  [self initializeWithOptionalModules];

  // We finally set our autosave window frame name and restore the one from the user's defaults.
  [[self window] setFrameAutosaveName: @"PreferencesWindow"];
  [[self window] setFrameUsingName: @"PreferencesWindow"];

  return self;
}


//
//
//
- (void) dealloc
{
  [self _releaseLoadedBundles];
  RELEASE(_allModules);
  [super dealloc];
}


//
// delegate methods
//
- (void) windowDidLoad
{
  // We maintain an array of opened modules
  _allModules = [[NSMutableDictionary alloc] initWithCapacity: 10];

  [MailAppearance styleWindow: [self window]];
}


//
// The strip of icons that chooses the pane is shown whole, without a
// scroller: the window is made as wide as the icons need.
//
- (void) _fitIconStrip
{
  NSRect aBoxFrame, aScrollFrame;
  NSSize aContentSize;
  CGFloat aMissingWidth, aStripHeight, aDelta;

  // Room for the caption under each icon.
  [matrix setCellSize: NSMakeSize(PREFERENCES_ICON_WIDTH, PREFERENCES_ICON_HEIGHT)];
  [matrix sizeToCells];

  aMissingWidth = NSWidth([matrix frame]) - [scrollView contentSize].width;

  if (aMissingWidth != 0)
    {
      aContentSize = [[[self window] contentView] frame].size;
      [[self window] setContentSize: NSMakeSize(aContentSize.width + aMissingWidth, aContentSize.height)];
    }

  [scrollView setHasHorizontalScroller: NO];

  // What the scroller took above the box goes to the box.
  aStripHeight = NSHeight([matrix frame]) + 2;
  aScrollFrame = [scrollView frame];
  aDelta = NSHeight(aScrollFrame) - aStripHeight;

  // The pane below is as wide as the strip.
  aBoxFrame = [box frame];
  aBoxFrame.size.width = NSWidth(aScrollFrame);
  [box setFrame: aBoxFrame];

  if (aDelta > 0)
    {
      aBoxFrame = [box frame];
      aScrollFrame.origin.y += aDelta;
      aScrollFrame.size.height = aStripHeight;
      aBoxFrame.size.height += aDelta;
      [scrollView setFrame: aScrollFrame];
      [box setFrame: aBoxFrame];
    }
}


//
//
//
- (void) windowWillClose: (NSNotification *) theNotification
{  
  // We save our current preferences setting (expert/normal)
  [[NSUserDefaults standardUserDefaults] setInteger: _mode  forKey: @"PREFERENCES_MODE"];
  AUTORELEASE(self);
  singleInstance = nil;
}


//
//
//
- (void) handleCellAction: (id) sender
{  
  id aModule;
  
  aModule = [_allModules objectForKey: [[matrix selectedCell] title]];

  if (aModule)
    {
      [self addModuleToView: aModule];
    }
  else
    {
      NSLog(@"Unable to load the %@ bundle.", [[matrix selectedCell] title]);
    }
}


//
// action methods
//
- (IBAction) cancelClicked: (id) sender
{
  [self close];
}


//
//
//
- (IBAction) expertClicked: (id) sender
{
  NSString *titleOfSelectedCell;
  
  titleOfSelectedCell = [[matrix selectedCell] stringValue];

  if (_mode == MODE_STANDARD)
    {
      [self setMode: MODE_EXPERT];
    }
  else
    {
      [self setMode: MODE_STANDARD];  
    }

  // We initialize our matrix with the standard modules
  [self initializeWithStandardModules];

  // We then add our additional modules
  [self initializeWithOptionalModules];

  // We reselect the right cell
  [self _selectCellWithTitle: titleOfSelectedCell];
}



//
//
//
- (IBAction) saveAndClose: (id) sender
{
  [self savePreferences: nil];
  [self close];
}


//
//
//
- (IBAction) savePreferences: (id) sender
{
  NSArray *allNames;
  id<PreferencesModule> aModule;
  int i;

  allNames = [_allModules allKeys];

  for (i = 0; i < [allNames count]; i++)
    {
      aModule = [_allModules objectForKey: [allNames objectAtIndex: i]];

      if ( [aModule hasChangesPending] )
	{
	  [aModule saveChanges];
	}
    }
  
  [[NSUserDefaults standardUserDefaults] synchronize];
}


//
// other methods
//
- (void) addModuleToView: (id<PreferencesModule>) aModule
{    
  if (aModule == nil)
    {
      return;
    }

  if ([box contentView] != [aModule view])
    {
      [box setContentView: [aModule view]];
      [box setTitle: [aModule name]];
    }
}


//
//
//
- (void) initializeWithStandardModules
{
  if (_mode == MODE_STANDARD)
    {
      [matrix renewRows: 1  columns: 6];
      [self _initializeModuleWithName: @"Account"   atIndex: 0];
      [self _initializeModuleWithName: @"Viewing"   atIndex: 1];
      [self _initializeModuleWithName: @"Receiving" atIndex: 2];
      [self _initializeModuleWithName: @"Compose"   atIndex: 3];
      [self _initializeModuleWithName: @"Fonts"     atIndex: 4];
      [self _initializeModuleWithName: @"Colors"    atIndex: 5];
    }
  else
    {
      [matrix renewRows: 1  columns: 10];
      [self _initializeModuleWithName: @"Account"   atIndex: 0];
      [self _initializeModuleWithName: @"Viewing"   atIndex: 1];
      [self _initializeModuleWithName: @"Sending"   atIndex: 2];
      [self _initializeModuleWithName: @"Receiving" atIndex: 3];
      [self _initializeModuleWithName: @"Compose"   atIndex: 4];
      [self _initializeModuleWithName: @"Fonts"     atIndex: 5];
      [self _initializeModuleWithName: @"Colors"    atIndex: 6];
      [self _initializeModuleWithName: @"MIME"      atIndex: 7];
      [self _initializeModuleWithName: @"Filtering" atIndex: 8];
      [self _initializeModuleWithName: @"Advanced"  atIndex: 9];
    }
}


//
//
//
- (void) initializeWithOptionalModules
{
  int i;
  
  for (i = 0; i < [[GNUMail allBundles] count]; i++)
    {
      id<GNUMailBundle> aBundle;
      
      aBundle = [[GNUMail allBundles] objectAtIndex: i];
      
      if ( [aBundle hasPreferencesPanel] )
	{
	  id<PreferencesModule> aModule;
	  NSButtonCell *aButtonCell;
	  int column;

	  // We get our Preferences module and we add it to our matrix.
	  aModule = (id<PreferencesModule>)[aBundle preferencesModule];

	  // A bundle that is installed twice must not show twice.
	  if ([_allModules objectForKey: [aModule name]])
	    {
	      continue;
	    }

	  // We add our column
	  [matrix addColumn];
	  column = ([matrix numberOfColumns] - 1);

	  [_allModules setObject: aModule  forKey: [aModule name]];
	  
	  aButtonCell = [matrix cellAtRow: 0
				column: column];
	  
	  [aButtonCell setTag: column];
	  [aButtonCell setTitle: [aModule name]];
	  [aButtonCell setFont: METRICS_FONT_SYSTEM_REGULAR_11];
	  [aButtonCell setImage: [aModule image]];
	}
    }

  [matrix sizeToCells];
  [matrix setNeedsDisplay: YES];

  [self _fitIconStrip];
}


//
// access/mutation methods
//
- (NSMatrix *) matrix
{
  return matrix;
}


//
//
//
- (int) mode
{
  return _mode;
}


//
//
//
- (void) setMode: (int) theMode 
{
  _mode = theMode;
  
  if (_mode == MODE_EXPERT)
    {
      [expert setTitle: _(@"Standard")];
    }
  else
    {
      [expert setTitle: _(@"Expert")];
    }
}



//
// class methods
//
+ (id) singleInstance
{
  if ( !singleInstance )
    {
      singleInstance = [[PreferencesWindowController alloc] initWithWindowNibName: @"PreferencesWindow"];

      // We select the first cell in our matrix
      [[singleInstance matrix] selectCellAtRow: 0  column: 0];
      [singleInstance handleCellAction: [singleInstance matrix]];
    }
  else
    {
      return nil;
    }

  return singleInstance;
}

@end


//
// Private interface
//
@implementation PreferencesWindowController (Private)

- (void) _initializeModuleWithName: (NSString *) theName
			   atIndex: (int) theIndex
{
  id<PreferencesModule> aModule;
  NSButtonCell *aButtonCell;

  aModule = [NSBundle instanceForBundleWithName: theName];

  if (!aModule)
    {
      NSLog(@"Unable to initialize module %@", theName);
      return;
    }

  [_allModules setObject: aModule  forKey: _(theName)];
  
  aButtonCell = [matrix cellAtRow: 0  column: theIndex];
  [aButtonCell setTag: theIndex];
  [aButtonCell setTitle: [aModule name]];
  [aButtonCell setFont: METRICS_FONT_SYSTEM_REGULAR_11];
  [aButtonCell setImage: [aModule image]];
}


//
//
//
- (void) _releaseLoadedBundles
{
  NSEnumerator *aEnumerator;
  id aModule;
  
  aEnumerator = [_allModules objectEnumerator];
 
  while ((aModule = [aEnumerator nextObject]))
    {
      RELEASE(aModule);
    }
}


//
//
//
- (void) _selectCellWithTitle: (NSString *) theTitle
{
  int i;

  for (i = 0; i < [matrix numberOfColumns]; i++)
    {
      if ( [theTitle isEqualToString: [[matrix cellAtRow: 0  column: i] stringValue]] )
        {
          [matrix selectCellAtRow: 0  column: i];
          [self addModuleToView: [_allModules objectForKey: theTitle]];
          return;
        }
    }

  // No cell found, we select the first one and perform the action
  [[singleInstance matrix] selectCellAtRow: 0  column: 0];
  [singleInstance handleCellAction: matrix];
  [self addModuleToView: [_allModules objectForKey: [[matrix selectedCell] title]]];
}


@end
