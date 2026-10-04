/*
**  GmailOAuth.h
**
**  Sign-in to a Google (Gmail) account with OAuth 2.0 for installed
**  applications: the system browser, a redirect to a loopback address and
**  PKCE.  No password is asked for or stored; the mail servers are reached
**  with the XOAUTH2 mechanism and an access token.
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#ifndef _GNUMail_H_GmailOAuth
#define _GNUMail_H_GmailOAuth

#import <Foundation/Foundation.h>

@interface GmailOAuth : NSObject

/*
 * The OAuth client the application signs in with.  Google hands it out for
 * a project of the developer (a "Desktop app" client in the Cloud Console);
 * it is read from the GMAIL_OAUTH_CLIENT_ID and GMAIL_OAUTH_CLIENT_SECRET
 * defaults, or from GmailOAuth.plist (keys ClientID, ClientSecret) in the
 * application's resources.  nil when there is none.
 */
+ (NSString *) clientID;
+ (NSString *) clientSecret;

/*
 * A current access token for the account with that address, refreshed from
 * the stored refresh token when the one at hand has expired.  Blocks while
 * it asks Google.  nil if the account has not been signed in or Google
 * refuses the refresh.
 */
+ (NSString *) accessTokenForUsername: (NSString *) theUsername;

/*
 * The pieces of the sign-in.  Class methods that need no network, so that
 * they can be checked on their own.
 */
+ (NSData *) randomDataOfLength: (NSUInteger) theLength;
+ (NSString *) base64URLStringFromData: (NSData *) theData;
+ (NSData *) sha256OfData: (NSData *) theData;
+ (NSString *) codeChallengeForVerifier: (NSString *) theVerifier;
+ (NSDictionary *) parametersFromQuery: (NSString *) theQuery;
+ (NSURL *) authorizationURLWithClientID: (NSString *) theClientID
			     redirectURI: (NSString *) theRedirectURI
				   state: (NSString *) theState
			   codeChallenge: (NSString *) theCodeChallenge;
+ (NSMutableDictionary *) accountDictionaryForAddress: (NSString *) theAddress
						 name: (NSString *) theName;

/*
 * The token endpoint, replaced by the tests; nil restores Google's.
 */
+ (void) setTokenEndpoint: (NSString *) theEndpoint;

/*
 * Where the refresh tokens are kept, one file per address, readable by the
 * user only.  ~/Library/Mail/GmailTokens unless it is set (by the tests).
 */
+ (void) setTokenDirectory: (NSString *) theDirectory;
+ (NSString *) tokenDirectory;
+ (BOOL) storeRefreshToken: (NSString *) theToken  forAddress: (NSString *) theAddress;

/*
 * Removes the stored access of every address that is not in the list, and
 * forgets the access tokens that were made from it.  An account that has been
 * deleted leaves nothing behind.
 */
+ (void) removeTokensExceptForAddresses: (NSArray *) theAddresses;

/*
 * The name and address of the account the access token belongs to.
 */
+ (NSDictionary *) userInfoForAccessToken: (NSString *) theToken
				    error: (NSString **) theError;

/*
 * Exchanges the authorization code for tokens (or the refresh token for an
 * access token, when theCode is nil) and returns Google's answer as a
 * dictionary, or nil with the reason in theError.
 */
+ (NSDictionary *) tokensForCode: (NSString *) theCode
		    codeVerifier: (NSString *) theVerifier
		     redirectURI: (NSString *) theRedirectURI
		    refreshToken: (NSString *) theRefreshToken
			   error: (NSString **) theError;

/*
 * Listens on an ephemeral port of the loopback address; returns the socket
 * (-1 on failure) and the port.  +waitForRedirectOnListener:timeout: waits
 * for the browser to be sent there, answers it with a page and returns the
 * query of that request (code and state, or the error), or nil on timeout or
 * when the socket has been closed from another thread.
 */
+ (int) openLoopbackListener: (int *) thePort;
+ (NSString *) waitForRedirectOnListener: (int) theSocket
				 timeout: (NSTimeInterval) theTimeout;
+ (NSString *) waitForRedirectOnListener: (int) theSocket
				 timeout: (NSTimeInterval) theTimeout
			      cancelFlag: (volatile BOOL *) theCancelFlag;

@end

#endif
