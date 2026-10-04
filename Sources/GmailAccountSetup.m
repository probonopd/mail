/*
**  GmailAccountSetup.m
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#import "GmailAccountSetup.h"

#import <AppKit/AppKit.h>
#import <Pantomime/CWURLName.h>

#import "Constants.h"
#import "GNUMail.h"
#import "GmailOAuth.h"
#import "MailboxManagerController.h"
#import "Utilities.h"

#import <unistd.h>


//
// The panel that stays up while the user signs in in the browser, and the
// thread that waits for the browser to come back.
//
@interface GmailSignIn : NSObject
{
  int listener;
  volatile BOOL cancelled;
  NSString *redirectQuery;
  NSPanel *panel;
}
- (NSString *) runWithListener: (int) theListener;
@end

@implementation GmailSignIn

- (void) dealloc
{
  RELEASE(redirectQuery);
  RELEASE(panel);
  [super dealloc];
}

- (void) listen: (id) ignored
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString *query;

  query = [GmailOAuth waitForRedirectOnListener: listener
					timeout: 300.0
				     cancelFlag: &cancelled];
  [self performSelectorOnMainThread: @selector(redirectArrived:)
			 withObject: query
		      waitUntilDone: NO];
  RELEASE(pool);
}

- (void) redirectArrived: (NSString *) theQuery
{
  ASSIGN(redirectQuery, theQuery);
  [NSApp stopModal];
}

- (void) cancel: (id) sender
{
  cancelled = YES;
  [NSApp stopModal];
}

- (NSString *) runWithListener: (int) theListener
{
  NSTextField *aLabel;
  NSProgressIndicator *aBar;
  NSButton *aButton;

  listener = theListener;

  panel = [[NSPanel alloc] initWithContentRect: NSMakeRect(0, 0, 400, 140)
				     styleMask: NSTitledWindowMask
				       backing: NSBackingStoreBuffered
					 defer: NO];
  [panel setTitle: _(@"Add Gmail Account")];
  [panel center];

  aLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(20, 80, 360, 40)];
  [aLabel setStringValue: _(@"Sign in to your Google account in the browser that has just opened, then come back here.")];
  [aLabel setBezeled: NO];
  [aLabel setDrawsBackground: NO];
  [aLabel setEditable: NO];
  [aLabel setSelectable: NO];
  [[panel contentView] addSubview: aLabel];
  RELEASE(aLabel);

  aBar = [[NSProgressIndicator alloc] initWithFrame: NSMakeRect(20, 56, 360, 12)];
  [aBar setStyle: NSProgressIndicatorBarStyle];
  [aBar setIndeterminate: YES];
  [aBar startAnimation: nil];
  [[panel contentView] addSubview: aBar];
  RELEASE(aBar);

  aButton = [[NSButton alloc] initWithFrame: NSMakeRect(290, 16, 90, 24)];
  [aButton setTitle: _(@"Cancel")];
  [aButton setTarget: self];
  [aButton setAction: @selector(cancel:)];
  [aButton setKeyEquivalent: @"\e"];
  [[panel contentView] addSubview: aButton];
  RELEASE(aButton);

  [NSThread detachNewThreadSelector: @selector(listen:)  toTarget: self  withObject: nil];

  [NSApp runModalForWindow: panel];
  [panel orderOut: nil];
  cancelled = YES;                         // lets the thread end if it still waits

  return AUTORELEASE(RETAIN(redirectQuery));
}

@end



@implementation GmailAccountSetup

+ (void) startObservingAccounts
{
  [[NSNotificationCenter defaultCenter] addObserver: self
					   selector: @selector(accountsHaveChanged:)
					       name: AccountsHaveChanged
					     object: nil];
}

+ (void) accountsHaveChanged: (NSNotification *) theNotification
{
  NSMutableArray *someAddresses;
  NSDictionary *someAccounts;
  NSEnumerator *anEnumerator;
  NSDictionary *anAccount;

  someAccounts = [[NSUserDefaults standardUserDefaults] objectForKey: @"ACCOUNTS"];
  someAddresses = [NSMutableArray array];
  anEnumerator = [someAccounts objectEnumerator];

  while ((anAccount = [anEnumerator nextObject]))
    {
      NSDictionary *aReceive = [anAccount objectForKey: @"RECEIVE"];

      if ([[aReceive objectForKey: @"AUTH_MECHANISM"] isEqual: @"XOAUTH2"] && [aReceive objectForKey: @"USERNAME"])
	{
	  [someAddresses addObject: [aReceive objectForKey: @"USERNAME"]];
	}
    }

  [GmailOAuth removeTokensExceptForAddresses: someAddresses];
}

+ (void) _failWith: (NSString *) theMessage
{
  NSRunAlertPanel(_(@"Gmail"), @"%@", _(@"OK"), nil, nil, theMessage);
}

+ (void) addAccount
{
  NSString *aClientID, *anError, *aVerifier, *aState, *aRedirect, *aQuery, *anAddress;
  NSData *someRandom;
  NSDictionary *someParameters, *someTokens, *anInfo;
  NSMutableDictionary *someAccounts, *anAccount;
  GmailSignIn *aSignIn;
  int aPort, aSocket;

  aClientID = [GmailOAuth clientID];
  if (aClientID == nil)
    {
      [self _failWith: _(@"Gmail sign-in is not set up in this installation: there is no Google OAuth client. "
			 @"Create a \"Desktop app\" client at console.cloud.google.com and set its ID in the "
			 @"GMAIL_OAUTH_CLIENT_ID default (and GMAIL_OAUTH_CLIENT_SECRET).")];
      return;
    }

  // PKCE: the verifier stays here, only its hash goes to Google.
  someRandom = [GmailOAuth randomDataOfLength: 32];
  aState = [GmailOAuth base64URLStringFromData: [GmailOAuth randomDataOfLength: 16]];
  if (someRandom == nil || [aState length] == 0)
    {
      [self _failWith: _(@"Could not get random numbers for the sign-in.")];
      return;
    }
  aVerifier = [GmailOAuth base64URLStringFromData: someRandom];

  aSocket = [GmailOAuth openLoopbackListener: &aPort];
  if (aSocket < 0)
    {
      [self _failWith: _(@"Could not listen for the answer of the browser.")];
      return;
    }
  aRedirect = [NSString stringWithFormat: @"http://127.0.0.1:%d", aPort];

  if (![[NSWorkspace sharedWorkspace] openURL: [GmailOAuth authorizationURLWithClientID: aClientID
									redirectURI: aRedirect
									      state: aState
								      codeChallenge: [GmailOAuth codeChallengeForVerifier: aVerifier]]])
    {
      close(aSocket);
      [self _failWith: _(@"Could not open the browser.")];
      return;
    }

  aSignIn = [[GmailSignIn alloc] init];
  aQuery = [aSignIn runWithListener: aSocket];
  RELEASE(aSignIn);
  close(aSocket);

  if (aQuery == nil)
    {
      return;                              // cancelled, or nobody signed in in time
    }

  someParameters = [GmailOAuth parametersFromQuery: aQuery];
  if (![[someParameters objectForKey: @"state"] isEqualToString: aState] ||
      [[someParameters objectForKey: @"code"] length] == 0)
    {
      [self _failWith: [NSString stringWithFormat: _(@"Google did not give access: %@"),
				 ([someParameters objectForKey: @"error"] ?: _(@"the answer does not belong to this sign-in"))]];
      return;
    }

  anError = nil;
  someTokens = [GmailOAuth tokensForCode: [someParameters objectForKey: @"code"]
		      codeVerifier: aVerifier
		       redirectURI: aRedirect
		      refreshToken: nil
			     error: &anError];
  if ([[someTokens objectForKey: @"refresh_token"] length] == 0)
    {
      [self _failWith: [NSString stringWithFormat: _(@"Google did not hand out the access: %@"),
				 (anError ?: _(@"no refresh token"))]];
      return;
    }

  anInfo = [GmailOAuth userInfoForAccessToken: [someTokens objectForKey: @"access_token"]  error: &anError];
  anAddress = [anInfo objectForKey: @"email"];
  if ([anAddress length] == 0)
    {
      [self _failWith: [NSString stringWithFormat: _(@"Could not find out the address of the account: %@"),
				 (anError ?: @"")]];
      return;
    }

  if (![GmailOAuth storeRefreshToken: [someTokens objectForKey: @"refresh_token"]  forAddress: anAddress])
    {
      [self _failWith: _(@"Could not save the access to the account.")];
      return;
    }

  // The account, in the application's accounts; an earlier one for the
  // same address is replaced (that is how the sign-in is renewed).
  someAccounts = [NSMutableDictionary dictionaryWithDictionary:
		   [[NSUserDefaults standardUserDefaults] objectForKey: @"ACCOUNTS"]];
  anAccount = [GmailOAuth accountDictionaryForAddress: anAddress  name: [anInfo objectForKey: @"name"]];
  if ([Utilities defaultAccountName] == nil)
    {
      [anAccount setObject: [NSNumber numberWithBool: YES]  forKey: @"DEFAULT"];
    }
  [someAccounts setObject: anAccount  forKey: anAddress];

  [[NSUserDefaults standardUserDefaults] setObject: someAccounts  forKey: @"ACCOUNTS"];
  [[NSUserDefaults standardUserDefaults] synchronize];

  [[NSNotificationCenter defaultCenter] postNotificationName: AccountsHaveChanged
						      object: nil
						    userInfo: nil];

  // Straight to the mail: the Inbox of the account opens.
  {
    CWURLName *anURLName;

    anURLName = [[CWURLName alloc] initWithString: [[anAccount objectForKey: @"MAILBOXES"] objectForKey: @"INBOXFOLDERNAME"]
					     path: [[NSUserDefaults standardUserDefaults] objectForKey: @"LOCALMAILDIR"]];
    [[MailboxManagerController singleInstance] openFolderWithURLName: anURLName  sender: [NSApp delegate]];
    RELEASE(anURLName);
  }
}

@end
