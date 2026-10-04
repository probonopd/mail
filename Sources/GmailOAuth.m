/*
**  GmailOAuth.m
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#import "GmailOAuth.h"

#import <Pantomime/NSData+Extensions.h>

#import "Constants.h"

#import <AppKit/AppKit.h>
#import <errno.h>
#import <string.h>
#import <unistd.h>
#import <sys/select.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <netinet/in.h>
#import <arpa/inet.h>

static NSString *AuthorizationEndpoint = @"https://accounts.google.com/o/oauth2/v2/auth";
static NSString *DefaultTokenEndpoint = @"https://oauth2.googleapis.com/token";
static NSString *UserInfoEndpoint = @"https://openidconnect.googleapis.com/v1/userinfo";

/* The whole mailbox (IMAP, SMTP), and the address of the account. */
static NSString *GmailScope = @"https://mail.google.com/ email profile";

static NSString *tokenEndpoint = nil;
static NSString *tokenDirectory = nil;
static NSMutableDictionary *accessTokens = nil;    // address -> {Token, Expires}

#pragma mark - SHA-256

static const uint32_t K256[64] = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))

static void sha256_block(uint32_t h[8], const unsigned char *p)
{
  uint32_t w[64], a, b, c, d, e, f, g, hh, t1, t2;
  int i;

  for (i = 0; i < 16; i++)
    {
      w[i] = ((uint32_t)p[4*i] << 24) | ((uint32_t)p[4*i+1] << 16) | ((uint32_t)p[4*i+2] << 8) | p[4*i+3];
    }
  for (i = 16; i < 64; i++)
    {
      uint32_t s0 = ROTR(w[i-15], 7) ^ ROTR(w[i-15], 18) ^ (w[i-15] >> 3);
      uint32_t s1 = ROTR(w[i-2], 17) ^ ROTR(w[i-2], 19) ^ (w[i-2] >> 10);
      w[i] = w[i-16] + s0 + w[i-7] + s1;
    }

  a = h[0]; b = h[1]; c = h[2]; d = h[3]; e = h[4]; f = h[5]; g = h[6]; hh = h[7];
  for (i = 0; i < 64; i++)
    {
      t1 = hh + (ROTR(e, 6) ^ ROTR(e, 11) ^ ROTR(e, 25)) + ((e & f) ^ (~e & g)) + K256[i] + w[i];
      t2 = (ROTR(a, 2) ^ ROTR(a, 13) ^ ROTR(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
      hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
  h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
}

@interface GmailOAuth (Private)
+ (NSDictionary *) _bundledClient;
+ (NSString *) _escaped: (NSString *) theString;
@end

@implementation GmailOAuth

#pragma mark - The client

+ (NSString *) clientID
{
  NSString *anID;

  anID = [[NSUserDefaults standardUserDefaults] stringForKey: @"GMAIL_OAUTH_CLIENT_ID"];
  if ([anID length] == 0)
    {
      anID = [[self _bundledClient] objectForKey: @"ClientID"];
    }
  return ([anID length] > 0 ? anID : nil);
}

+ (NSString *) clientSecret
{
  NSString *aSecret;

  aSecret = [[NSUserDefaults standardUserDefaults] stringForKey: @"GMAIL_OAUTH_CLIENT_SECRET"];
  if ([aSecret length] == 0)
    {
      aSecret = [[self _bundledClient] objectForKey: @"ClientSecret"];
    }
  return ([aSecret length] > 0 ? aSecret : nil);
}

+ (NSDictionary *) _bundledClient
{
  NSString *aPath;

  aPath = [[NSBundle mainBundle] pathForResource: @"GmailOAuth"  ofType: @"plist"];
  return (aPath ? [NSDictionary dictionaryWithContentsOfFile: aPath] : nil);
}

+ (void) setTokenEndpoint: (NSString *) theEndpoint
{
  ASSIGN(tokenEndpoint, theEndpoint);
}

#pragma mark - Pieces of the sign-in

+ (NSData *) randomDataOfLength: (NSUInteger) theLength
{
  NSMutableData *someData;
  FILE *aFile;
  size_t aCount;

  someData = [NSMutableData dataWithLength: theLength];
  aFile = fopen("/dev/urandom", "rb");
  if (aFile == NULL)
    {
      return nil;
    }
  aCount = fread([someData mutableBytes], 1, theLength, aFile);
  fclose(aFile);
  return (aCount == theLength ? someData : nil);
}

+ (NSString *) base64URLStringFromData: (NSData *) theData
{
  NSString *aString;

  aString = [[NSString alloc] initWithData: [theData encodeBase64WithLineLength: 0]
				  encoding: NSASCIIStringEncoding];
  aString = [aString stringByReplacingOccurrencesOfString: @"+"  withString: @"-"];
  aString = [aString stringByReplacingOccurrencesOfString: @"/"  withString: @"_"];
  aString = [aString stringByReplacingOccurrencesOfString: @"="  withString: @""];
  return AUTORELEASE(RETAIN(aString));
}

+ (NSData *) sha256OfData: (NSData *) theData
{
  uint32_t h[8] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
  const unsigned char *bytes = [theData bytes];
  NSUInteger length = [theData length], i;
  unsigned char block[128], out[32];
  uint64_t bits = (uint64_t)length * 8;
  NSUInteger rest = length % 64, padded;

  for (i = 0; i + 64 <= length; i += 64)
    {
      sha256_block(h, bytes + i);
    }

  memset(block, 0, sizeof(block));
  memcpy(block, bytes + length - rest, rest);
  block[rest] = 0x80;
  padded = (rest < 56 ? 64 : 128);
  for (i = 0; i < 8; i++)
    {
      block[padded - 1 - i] = (unsigned char)(bits >> (8 * i));
    }
  sha256_block(h, block);
  if (padded == 128)
    {
      sha256_block(h, block + 64);
    }

  for (i = 0; i < 8; i++)
    {
      out[4*i] = h[i] >> 24; out[4*i+1] = h[i] >> 16; out[4*i+2] = h[i] >> 8; out[4*i+3] = h[i];
    }
  return [NSData dataWithBytes: out  length: 32];
}

+ (NSString *) codeChallengeForVerifier: (NSString *) theVerifier
{
  return [self base64URLStringFromData:
		 [self sha256OfData: [theVerifier dataUsingEncoding: NSASCIIStringEncoding]]];
}

+ (NSString *) _escaped: (NSString *) theString
{
  NSCharacterSet *anUnreserved;

  anUnreserved = [NSCharacterSet characterSetWithCharactersInString:
	 @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"];
  return [theString stringByAddingPercentEncodingWithAllowedCharacters: anUnreserved];
}

+ (NSDictionary *) parametersFromQuery: (NSString *) theQuery
{
  NSMutableDictionary *someParameters;
  NSEnumerator *anEnumerator;
  NSString *aPair;

  someParameters = [NSMutableDictionary dictionary];
  anEnumerator = [[theQuery componentsSeparatedByString: @"&"] objectEnumerator];

  while ((aPair = [anEnumerator nextObject]))
    {
      NSRange aRange;
      NSString *aKey, *aValue;

      aRange = [aPair rangeOfString: @"="];
      if (aRange.location == NSNotFound)
	{
	  continue;
	}
      aKey = [aPair substringToIndex: aRange.location];
      aValue = [[aPair substringFromIndex: aRange.location + 1]
		 stringByReplacingOccurrencesOfString: @"+"  withString: @" "];
      [someParameters setObject: ([aValue stringByRemovingPercentEncoding] ?: aValue)
			 forKey: ([aKey stringByRemovingPercentEncoding] ?: aKey)];
    }
  return someParameters;
}

+ (NSURL *) authorizationURLWithClientID: (NSString *) theClientID
			     redirectURI: (NSString *) theRedirectURI
				   state: (NSString *) theState
			   codeChallenge: (NSString *) theCodeChallenge
{
  return [NSURL URLWithString: [NSString stringWithFormat:
	  @"%@?client_id=%@&redirect_uri=%@&response_type=code&scope=%@&state=%@"
	  @"&code_challenge=%@&code_challenge_method=S256&access_type=offline&prompt=consent",
	  AuthorizationEndpoint,
	  [self _escaped: theClientID], [self _escaped: theRedirectURI], [self _escaped: GmailScope],
	  [self _escaped: theState], [self _escaped: theCodeChallenge]]];
}

#pragma mark - The loopback address

+ (int) openLoopbackListener: (int *) thePort
{
  struct sockaddr_in anAddress;
  socklen_t aLength = sizeof(anAddress);
  int aSocket;

  aSocket = socket(AF_INET, SOCK_STREAM, 0);
  if (aSocket < 0)
    {
      return -1;
    }

  memset(&anAddress, 0, sizeof(anAddress));
  anAddress.sin_family = AF_INET;
  anAddress.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  anAddress.sin_port = 0;

  if (bind(aSocket, (struct sockaddr *)&anAddress, sizeof(anAddress)) != 0 ||
      listen(aSocket, 4) != 0 ||
      getsockname(aSocket, (struct sockaddr *)&anAddress, &aLength) != 0)
    {
      close(aSocket);
      return -1;
    }

  *thePort = ntohs(anAddress.sin_port);
  return aSocket;
}

+ (NSString *) waitForRedirectOnListener: (int) theSocket
				 timeout: (NSTimeInterval) theTimeout
{
  return [self waitForRedirectOnListener: theSocket  timeout: theTimeout  cancelFlag: NULL];
}

+ (NSString *) waitForRedirectOnListener: (int) theSocket
				 timeout: (NSTimeInterval) theTimeout
			      cancelFlag: (volatile BOOL *) theCancelFlag
{
  NSDate *aDeadline;

  aDeadline = [NSDate dateWithTimeIntervalSinceNow: theTimeout];

  while ([aDeadline timeIntervalSinceNow] > 0 && !(theCancelFlag && *theCancelFlag))
    {
      struct timeval aWait = { 0, 500000 };
      fd_set aSet;
      char aBuffer[8192];
      ssize_t aCount;
      int aConnection;
      NSString *aRequest, *aTarget, *aQuery;
      NSRange aRange;
      const char *aReply;

      FD_ZERO(&aSet);
      FD_SET(theSocket, &aSet);
      if (select(theSocket + 1, &aSet, NULL, NULL, &aWait) <= 0)
	{
	  continue;
	}

      aConnection = accept(theSocket, NULL, NULL);
      if (aConnection < 0)
	{
	  continue;
	}

      // The request line arrives in the first bytes; the rest is not used.
      aWait.tv_sec = 2;
      aWait.tv_usec = 0;
      setsockopt(aConnection, SOL_SOCKET, SO_RCVTIMEO, &aWait, sizeof(aWait));
      aCount = recv(aConnection, aBuffer, sizeof(aBuffer) - 1, 0);
      aQuery = nil;

      if (aCount > 0)
	{
	  aBuffer[aCount] = 0;
	  aRequest = [NSString stringWithUTF8String: aBuffer];
	  aRange = [aRequest rangeOfString: @"\r\n"];
	  aTarget = (aRange.location != NSNotFound ? [aRequest substringToIndex: aRange.location] : aRequest);
	  // "GET /?code=...&state=... HTTP/1.1"
	  aRange = [aTarget rangeOfString: @"/?"];
	  if ([aTarget hasPrefix: @"GET "] && aRange.location != NSNotFound)
	    {
	      aTarget = [aTarget substringFromIndex: NSMaxRange(aRange)];
	      aRange = [aTarget rangeOfString: @" "];
	      aQuery = (aRange.location != NSNotFound ? [aTarget substringToIndex: aRange.location] : aTarget);
	    }
	}

      aReply = (aQuery
		? "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n"
		  "<html><body style=\"font-family: sans-serif; text-align: center; margin-top: 4em\">"
		  "<h2>You are signed in.</h2><p>You can close this window and go back to Mail.</p></body></html>"
		: "HTTP/1.1 404 Not Found\r\nConnection: close\r\nContent-Length: 0\r\n\r\n");
      send(aConnection, aReply, strlen(aReply), 0);
      close(aConnection);

      // Anything but the redirect (a favicon request, say) is answered and ignored.
      if (aQuery)
	{
	  return aQuery;
	}
    }

  return nil;
}

#pragma mark - Google

+ (NSDictionary *) _jsonFromRequest: (NSURLRequest *) theRequest
			      error: (NSString **) theError
{
  NSHTTPURLResponse *aResponse = nil;
  NSError *anError = nil;
  NSData *aData;
  id aResult;

  aData = [NSURLConnection sendSynchronousRequest: theRequest
				returningResponse: &aResponse
					    error: &anError];
  if (aData == nil)
    {
      if (theError) *theError = [anError localizedDescription];
      return nil;
    }

  aResult = [NSJSONSerialization JSONObjectWithData: aData  options: 0  error: NULL];
  if (![aResult isKindOfClass: [NSDictionary class]])
    {
      if (theError) *theError = [NSString stringWithFormat: _(@"Unexpected answer from Google (%d)."),
					  (int)[aResponse statusCode]];
      return nil;
    }

  if ([aResult objectForKey: @"error"])
    {
      id aReason = [aResult objectForKey: @"error_description"] ?: [aResult objectForKey: @"error"];
      if (theError) *theError = [aReason description];
      return nil;
    }
  return aResult;
}

+ (NSDictionary *) tokensForCode: (NSString *) theCode
		    codeVerifier: (NSString *) theVerifier
		     redirectURI: (NSString *) theRedirectURI
		    refreshToken: (NSString *) theRefreshToken
			   error: (NSString **) theError
{
  NSMutableURLRequest *aRequest;
  NSMutableString *aBody;
  NSString *aSecret;

  aBody = [NSMutableString stringWithFormat: @"client_id=%@", [self _escaped: [self clientID]]];
  aSecret = [self clientSecret];
  if (aSecret)
    {
      [aBody appendFormat: @"&client_secret=%@", [self _escaped: aSecret]];
    }

  if (theCode)
    {
      [aBody appendFormat: @"&grant_type=authorization_code&code=%@&code_verifier=%@&redirect_uri=%@",
	     [self _escaped: theCode], [self _escaped: theVerifier], [self _escaped: theRedirectURI]];
    }
  else
    {
      [aBody appendFormat: @"&grant_type=refresh_token&refresh_token=%@", [self _escaped: theRefreshToken]];
    }

  aRequest = [NSMutableURLRequest requestWithURL: [NSURL URLWithString: (tokenEndpoint ?: DefaultTokenEndpoint)]];
  [aRequest setHTTPMethod: @"POST"];
  [aRequest setValue: @"application/x-www-form-urlencoded"  forHTTPHeaderField: @"Content-Type"];
  [aRequest setHTTPBody: [aBody dataUsingEncoding: NSUTF8StringEncoding]];
  [aRequest setTimeoutInterval: 20.0];

  return [self _jsonFromRequest: aRequest  error: theError];
}

+ (NSDictionary *) userInfoForAccessToken: (NSString *) theToken
				    error: (NSString **) theError
{
  NSMutableURLRequest *aRequest;

  aRequest = [NSMutableURLRequest requestWithURL: [NSURL URLWithString: UserInfoEndpoint]];
  [aRequest setValue: [@"Bearer " stringByAppendingString: theToken]  forHTTPHeaderField: @"Authorization"];
  [aRequest setTimeoutInterval: 20.0];

  return [self _jsonFromRequest: aRequest  error: theError];
}

#pragma mark - Tokens

+ (void) setTokenDirectory: (NSString *) theDirectory
{
  ASSIGN(tokenDirectory, theDirectory);
}

+ (NSString *) tokenDirectory
{
  return (tokenDirectory ?: [NSString stringWithFormat: @"%@/Mail/GmailTokens",
			      [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
								 objectAtIndex: 0]]);
}

+ (NSString *) _tokenFileForAddress: (NSString *) theAddress
{
  return [[self tokenDirectory] stringByAppendingPathComponent: theAddress];
}

//
// The refresh token is the credential of the account; only the user may read it.
//
+ (BOOL) storeRefreshToken: (NSString *) theToken  forAddress: (NSString *) theAddress
{
  NSFileManager *aFileManager;
  NSString *aPath;

  aFileManager = [NSFileManager defaultManager];
  aPath = [self _tokenFileForAddress: theAddress];

  [aFileManager createDirectoryAtPath: [aPath stringByDeletingLastPathComponent]
	  withIntermediateDirectories: YES
			   attributes: [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 0700]
								   forKey: NSFilePosixPermissions]
				error: NULL];

  return [aFileManager createFileAtPath: aPath
			       contents: [NSPropertyListSerialization
					   dataFromPropertyList: [NSDictionary dictionaryWithObject: theToken
												 forKey: @"RefreshToken"]
							 format: NSPropertyListXMLFormat_v1_0
					       errorDescription: NULL]
			     attributes: [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 0600]
								     forKey: NSFilePosixPermissions]];
}

+ (void) removeTokensExceptForAddresses: (NSArray *) theAddresses
{
  NSFileManager *aFileManager;
  NSEnumerator *anEnumerator;
  NSString *aName;

  aFileManager = [NSFileManager defaultManager];
  anEnumerator = [[aFileManager contentsOfDirectoryAtPath: [self tokenDirectory]  error: NULL] objectEnumerator];

  while ((aName = [anEnumerator nextObject]))
    {
      if (![theAddresses containsObject: aName])
	{
	  [aFileManager removeItemAtPath: [[self tokenDirectory] stringByAppendingPathComponent: aName]  error: NULL];
	  @synchronized(self)
	    {
	      [accessTokens removeObjectForKey: aName];
	    }
	}
    }
}

+ (NSString *) accessTokenForUsername: (NSString *) theUsername
{
  NSDictionary *aCached, *aTokens;
  NSString *aRefreshToken, *anError;

  @synchronized(self)
    {
      aCached = [accessTokens objectForKey: theUsername];
      if (aCached && [[aCached objectForKey: @"Expires"] timeIntervalSinceNow] > 60.0)
	{
	  return [aCached objectForKey: @"Token"];
	}
    }

  aRefreshToken = [[NSDictionary dictionaryWithContentsOfFile: [self _tokenFileForAddress: theUsername]]
		    objectForKey: @"RefreshToken"];
  if (aRefreshToken == nil || [self clientID] == nil)
    {
      NSLog(@"Gmail: %@ is not signed in; add the account again.", theUsername);
      return nil;
    }

  anError = nil;
  aTokens = [self tokensForCode: nil  codeVerifier: nil  redirectURI: nil
		   refreshToken: aRefreshToken  error: &anError];
  if ([[aTokens objectForKey: @"access_token"] length] == 0)
    {
      NSLog(@"Gmail: could not refresh the access of %@: %@", theUsername, anError);
      return nil;
    }

  @synchronized(self)
    {
      if (accessTokens == nil)
	{
	  accessTokens = [[NSMutableDictionary alloc] init];
	}
      [accessTokens setObject: [NSDictionary dictionaryWithObjectsAndKeys:
		       [aTokens objectForKey: @"access_token"], @"Token",
		       [NSDate dateWithTimeIntervalSinceNow: [[aTokens objectForKey: @"expires_in"] doubleValue]], @"Expires",
		       nil]
		       forKey: theUsername];
    }
  return [aTokens objectForKey: @"access_token"];
}

#pragma mark - The account

+ (NSMutableDictionary *) accountDictionaryForAddress: (NSString *) theAddress
						 name: (NSString *) theName
{
  NSMutableDictionary *anAccount;
  NSString *aPrefix;

  aPrefix = [NSString stringWithFormat: @"imap://%@@imap.gmail.com/", theAddress];

  anAccount = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithBool: YES], @"ENABLED",
    [NSDictionary dictionaryWithObjectsAndKeys:
      (theName ?: theAddress), @"NAME",
      theAddress, @"EMAILADDR",
      nil], @"PERSONAL",
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt: IMAP], @"SERVERTYPE",
      @"imap.gmail.com", @"SERVERNAME",
      [NSNumber numberWithInt: 993], @"PORT",
      theAddress, @"USERNAME",
      [NSNumber numberWithInt: SECURITY_SSL], @"USESECURECONNECTION",
      @"XOAUTH2", @"AUTH_MECHANISM",
      [NSNumber numberWithInt: AUTOMATICALLY], @"RETRIEVEMETHOD",
      [NSNumber numberWithInt: 5], @"RETRIEVEMINUTES",
      [NSNumber numberWithInt: NSOnState], @"CHECKONSTARTUP",
      nil], @"RECEIVE",
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt: TRANSPORT_SMTP], @"TRANSPORT_METHOD",
      @"smtp.gmail.com", @"SMTP_HOST",
      [NSNumber numberWithInt: 465], @"SMTP_PORT",
      [NSNumber numberWithInt: SECURITY_SSL], @"USESECURECONNECTION",
      [NSNumber numberWithInt: NSOnState], @"SMTP_AUTH",
      theAddress, @"SMTP_USERNAME",
      @"XOAUTH2", @"SMTP_AUTH_MECHANISM",
      nil], @"SEND",
    [NSDictionary dictionaryWithObjectsAndKeys:
      [aPrefix stringByAppendingString: @"INBOX"], @"INBOXFOLDERNAME",
      [aPrefix stringByAppendingString: @"[Gmail]/Sent Mail"], @"SENTFOLDERNAME",
      [aPrefix stringByAppendingString: @"[Gmail]/Drafts"], @"DRAFTSFOLDERNAME",
      [aPrefix stringByAppendingString: @"[Gmail]/Trash"], @"TRASHFOLDERNAME",
      nil], @"MAILBOXES",
    nil];

  return anAccount;
}

@end
