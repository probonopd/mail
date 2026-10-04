/*
**  t_GmailOAuth.m
**
**  The sign-in to a Google account: the hash and the code challenge, the
**  authorization address, the redirect to the loopback address, the token
**  requests against a local stand-in for Google, and the account that is made.
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#import <Foundation/Foundation.h>
#import "Testing.h"
#import "GmailOAuth.h"
#import "Constants.h"

#import <unistd.h>
#import <string.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

static NSString *hex(NSData *theData)
{
  NSMutableString *aString = [NSMutableString string];
  const unsigned char *bytes = [theData bytes];
  NSUInteger i;

  for (i = 0; i < [theData length]; i++)
    {
      [aString appendFormat: @"%02x", bytes[i]];
    }
  return aString;
}

/* Sends a request line with a headers' end to the loopback port and returns what comes back. */
static NSString *request(int thePort, NSString *theText)
{
  struct sockaddr_in anAddress;
  char aBuffer[4096];
  ssize_t aCount;
  int aSocket = socket(AF_INET, SOCK_STREAM, 0);

  memset(&anAddress, 0, sizeof(anAddress));
  anAddress.sin_family = AF_INET;
  anAddress.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  anAddress.sin_port = htons(thePort);
  if (connect(aSocket, (struct sockaddr *)&anAddress, sizeof(anAddress)) != 0)
    {
      close(aSocket);
      return nil;
    }
  send(aSocket, [theText UTF8String], [theText length], 0);
  aCount = recv(aSocket, aBuffer, sizeof(aBuffer) - 1, 0);
  close(aSocket);
  if (aCount <= 0)
    {
      return @"";
    }
  aBuffer[aCount] = 0;
  return [NSString stringWithUTF8String: aBuffer];
}

/* A stand-in for Google's token endpoint: answers one POST with the given JSON and remembers the body. */
@interface FakeGoogle : NSObject
{
  int listener;
  int port;
  NSString *answer;
  NSString *lastBody;
  int requests;
}
- (id) initWithAnswer: (NSString *) theAnswer;
- (int) port;
- (NSString *) lastBody;
- (int) requests;
- (void) serve: (id) ignored;
- (void) stop;
@end

@implementation FakeGoogle

- (id) initWithAnswer: (NSString *) theAnswer
{
  self = [super init];
  ASSIGN(answer, theAnswer);
  listener = [GmailOAuth openLoopbackListener: &port];
  [NSThread detachNewThreadSelector: @selector(serve:)  toTarget: self  withObject: nil];
  return self;
}

- (int) port { return port; }
- (NSString *) lastBody { return lastBody; }
- (int) requests { return requests; }

- (void) stop
{
  close(listener);
  listener = -1;
}

- (void) serve: (id) ignored
{
  CREATE_AUTORELEASE_POOL(pool);

  while (listener >= 0)
    {
      char aBuffer[8192];
      ssize_t aCount;
      NSString *aRequest, *aReply;
      NSRange aRange;
      int aConnection;
      fd_set aSet;
      struct timeval aWait = { 0, 200000 };

      FD_ZERO(&aSet);
      FD_SET(listener, &aSet);
      if (select(listener + 1, &aSet, NULL, NULL, &aWait) <= 0)
	{
	  continue;
	}
      aConnection = accept(listener, NULL, NULL);
      if (aConnection < 0)
	{
	  continue;
	}
      aCount = recv(aConnection, aBuffer, sizeof(aBuffer) - 1, 0);
      if (aCount > 0)
	{
	  aBuffer[aCount] = 0;
	  aRequest = [NSString stringWithUTF8String: aBuffer];
	  // The body may come in a packet of its own; read on until it is all there.
	  {
	    NSRange aLength = [aRequest rangeOfString: @"Content-Length: " options: NSCaseInsensitiveSearch];
	    NSRange aEnd = [aRequest rangeOfString: @"\r\n\r\n"];
	    int expected = (aLength.location != NSNotFound ? [[aRequest substringFromIndex: NSMaxRange(aLength)] intValue] : 0);

	    while (aEnd.location != NSNotFound && (int)([aRequest length] - NSMaxRange(aEnd)) < expected)
	      {
		ssize_t more = recv(aConnection, aBuffer, sizeof(aBuffer) - 1, 0);
		if (more <= 0) break;
		aBuffer[more] = 0;
		aRequest = [aRequest stringByAppendingString: [NSString stringWithUTF8String: aBuffer]];
	      }
	  }
	  aRange = [aRequest rangeOfString: @"\r\n\r\n"];
	  ASSIGN(lastBody, (aRange.location != NSNotFound ? [aRequest substringFromIndex: NSMaxRange(aRange)] : @""));
	  requests++;
	  aReply = [NSString stringWithFormat: @"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
					       @"Content-Length: %d\r\nConnection: close\r\n\r\n%@",
					       (int)[answer length], answer];
	  send(aConnection, [aReply UTF8String], [aReply length], 0);
	}
      close(aConnection);
    }
  RELEASE(pool);
}

@end


int main(void)
{
  CREATE_AUTORELEASE_POOL(arp);
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  START_SET("sha256")
    {
      PASS([hex([GmailOAuth sha256OfData: [NSData data]])
	     isEqual: @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"],
	   "the hash of nothing");
      PASS([hex([GmailOAuth sha256OfData: [@"abc" dataUsingEncoding: NSASCIIStringEncoding]])
	     isEqual: @"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"],
	   "the hash of abc");
      PASS([hex([GmailOAuth sha256OfData:
		   [@"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" dataUsingEncoding: NSASCIIStringEncoding]])
	     isEqual: @"248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"],
	   "the hash of a message that needs a second block of padding");
    }
  END_SET("sha256")

  START_SET("pkce")
    {
      // The example of RFC 7636, appendix B.
      PASS([[GmailOAuth codeChallengeForVerifier: @"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"]
	     isEqual: @"E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"],
	   "the code challenge of the RFC's verifier");
      PASS([[GmailOAuth base64URLStringFromData: [NSData dataWithBytes: "\xfb\xff\xfe" length: 3]]
	     isEqual: @"-__-"],
	   "the base64 form for addresses has no plus, slash or padding");
      PASS([[GmailOAuth randomDataOfLength: 32] length] == 32 &&
	   ![[GmailOAuth randomDataOfLength: 32] isEqual: [GmailOAuth randomDataOfLength: 32]],
	   "random data has the length asked for and differs every time");
    }
  END_SET("pkce")

  START_SET("authorization address")
    {
      NSDictionary *someParameters;
      NSURL *anURL = [GmailOAuth authorizationURLWithClientID: @"id 1.apps"
						  redirectURI: @"http://127.0.0.1:5000"
							state: @"st&te"
						codeChallenge: @"chal"];

      someParameters = [GmailOAuth parametersFromQuery: [anURL query]];
      PASS([[anURL host] isEqual: @"accounts.google.com"] && [[anURL scheme] isEqual: @"https"], "it goes to Google over https");
      PASS([[someParameters objectForKey: @"client_id"] isEqual: @"id 1.apps"], "the client is in it");
      PASS([[someParameters objectForKey: @"redirect_uri"] isEqual: @"http://127.0.0.1:5000"], "the loopback address is the redirect");
      PASS([[someParameters objectForKey: @"state"] isEqual: @"st&te"], "the state survives the escaping");
      PASS([[someParameters objectForKey: @"scope"] isEqual: @"https://mail.google.com/ email profile"], "the scope is the mailbox and the address");
      PASS([[someParameters objectForKey: @"code_challenge_method"] isEqual: @"S256"], "the challenge is a hash");
      PASS([[someParameters objectForKey: @"access_type"] isEqual: @"offline"], "a refresh token is asked for");
      PASS(([[GmailOAuth parametersFromQuery: @"a=b%20c&d=e+f&g"] isEqual:
	     [NSDictionary dictionaryWithObjectsAndKeys: @"b c", @"a", @"e f", @"d", nil]]),
	   "a query is decoded, and a part without a value is left out");
    }
  END_SET("authorization address")

  START_SET("redirect to the loopback address")
    {
      int aPort = 0;
      int aSocket = [GmailOAuth openLoopbackListener: &aPort];
      __block NSString *aQuery = nil;
      __block BOOL aDone = NO;
      NSString *aReply;

      PASS(aSocket >= 0 && aPort > 0, "a port on the loopback address is opened");

      {
	NSThread *aThread = [[NSThread alloc] initWithBlock: ^{
	    CREATE_AUTORELEASE_POOL(inner);
	    aQuery = RETAIN([GmailOAuth waitForRedirectOnListener: aSocket  timeout: 10.0]);
	    aDone = YES;
	    RELEASE(inner);
	  }];
	[aThread start];
	RELEASE(aThread);
      }

      // A browser asks for the icon too; that is not the answer.
      PASS([request(aPort, @"GET /favicon.ico HTTP/1.1\r\nHost: x\r\n\r\n") hasPrefix: @"HTTP/1.1 404"],
	   "a request that is not the redirect is refused");
      aReply = request(aPort, @"GET /?code=4%2Fabc&state=xyz HTTP/1.1\r\nHost: x\r\n\r\n");
      PASS([aReply hasPrefix: @"HTTP/1.1 200"] && [aReply rangeOfString: @"signed in"].location != NSNotFound,
	   "the redirect is answered with a page");

      {
	int i;
	for (i = 0; i < 50 && !aDone; i++)
	  {
	    [NSThread sleepForTimeInterval: 0.1];
	  }
      }
      PASS([aQuery isEqual: @"code=4%2Fabc&state=xyz"], "the query of the redirect is handed back");
      close(aSocket);

      {
	volatile BOOL cancel = YES;
	aSocket = [GmailOAuth openLoopbackListener: &aPort];
	PASS([GmailOAuth waitForRedirectOnListener: aSocket  timeout: 10.0  cancelFlag: &cancel] == nil,
	     "waiting ends at once when it is cancelled");
	close(aSocket);
      }
      aSocket = [GmailOAuth openLoopbackListener: &aPort];
      PASS([GmailOAuth waitForRedirectOnListener: aSocket  timeout: 0.6] == nil, "waiting ends at the timeout");
      close(aSocket);
    }
  END_SET("redirect to the loopback address")

  START_SET("tokens")
    {
      NSString *aDirectory = [NSString stringWithFormat: @"/tmp/gmailoauth_t_%d", (int)getpid()];
      FakeGoogle *aGoogle;
      NSDictionary *someTokens;
      NSString *anError = nil;
      NSDictionary *aFile;

      [[NSFileManager defaultManager] removeItemAtPath: aDirectory  error: NULL];
      [GmailOAuth setTokenDirectory: aDirectory];
      [defaults setObject: @"client-1"  forKey: @"GMAIL_OAUTH_CLIENT_ID"];
      [defaults setObject: @"secret-1"  forKey: @"GMAIL_OAUTH_CLIENT_SECRET"];
      PASS([[GmailOAuth clientID] isEqual: @"client-1"] && [[GmailOAuth clientSecret] isEqual: @"secret-1"],
	   "the client comes from the defaults");

      aGoogle = [[FakeGoogle alloc] initWithAnswer:
		  @"{\"access_token\":\"at-1\",\"refresh_token\":\"rt-1\",\"expires_in\":3600,\"token_type\":\"Bearer\"}"];
      [GmailOAuth setTokenEndpoint: [NSString stringWithFormat: @"http://127.0.0.1:%d/token", [aGoogle port]]];

      someTokens = [GmailOAuth tokensForCode: @"the code"  codeVerifier: @"ver"  redirectURI: @"http://127.0.0.1:1"
			       refreshToken: nil  error: &anError];
      PASS([[someTokens objectForKey: @"refresh_token"] isEqual: @"rt-1"], "the code is exchanged for tokens");
      {
	NSDictionary *aBody = [GmailOAuth parametersFromQuery: [aGoogle lastBody]];
	PASS([[aBody objectForKey: @"grant_type"] isEqual: @"authorization_code"] &&
	     [[aBody objectForKey: @"code"] isEqual: @"the code"] &&
	     [[aBody objectForKey: @"code_verifier"] isEqual: @"ver"] &&
	     [[aBody objectForKey: @"client_id"] isEqual: @"client-1"] &&
	     [[aBody objectForKey: @"client_secret"] isEqual: @"secret-1"],
	     "the request carries the code, the verifier and the client");
      }

      // Signed in: the refresh token is kept, for the user only.
      PASS([GmailOAuth storeRefreshToken: @"rt-1"  forAddress: @"me@gmail.com"], "the refresh token is stored");
      aFile = [[NSFileManager defaultManager] attributesOfItemAtPath: [aDirectory stringByAppendingPathComponent: @"me@gmail.com"]
							       error: NULL];
      PASS([[aFile objectForKey: NSFilePosixPermissions] intValue] == 0600, "and only the user may read it");

      PASS([[GmailOAuth accessTokenForUsername: @"me@gmail.com"] isEqual: @"at-1"], "an access token is got with the refresh token");
      PASS([[[GmailOAuth parametersFromQuery: [aGoogle lastBody]] objectForKey: @"grant_type"] isEqual: @"refresh_token"] &&
	   [[[GmailOAuth parametersFromQuery: [aGoogle lastBody]] objectForKey: @"refresh_token"] isEqual: @"rt-1"],
	   "by a refresh request");
      {
	int before = [aGoogle requests];
	PASS([[GmailOAuth accessTokenForUsername: @"me@gmail.com"] isEqual: @"at-1"] && [aGoogle requests] == before,
	     "a token that has not expired is not asked for again");
      }
      PASS([GmailOAuth accessTokenForUsername: @"nobody@gmail.com"] == nil, "an account that was never signed in has no token");
      PASS([GmailOAuth storeRefreshToken: @"rt-2"  forAddress: @"gone@gmail.com"], "a second account is stored");
      [GmailOAuth removeTokensExceptForAddresses: [NSArray arrayWithObject: @"me@gmail.com"]];
      PASS(![[NSFileManager defaultManager] fileExistsAtPath: [aDirectory stringByAppendingPathComponent: @"gone@gmail.com"]] &&
	   [[NSFileManager defaultManager] fileExistsAtPath: [aDirectory stringByAppendingPathComponent: @"me@gmail.com"]],
	   "the access of a deleted account is removed and the other stays");
      [aGoogle stop];

      // Google refusing is reported, never guessed around.
      aGoogle = [[FakeGoogle alloc] initWithAnswer: @"{\"error\":\"invalid_grant\",\"error_description\":\"Token has been revoked.\"}"];
      [GmailOAuth setTokenEndpoint: [NSString stringWithFormat: @"http://127.0.0.1:%d/token", [aGoogle port]]];
      anError = nil;
      PASS([GmailOAuth tokensForCode: nil  codeVerifier: nil  redirectURI: nil  refreshToken: @"rt-x"  error: &anError] == nil &&
	   [anError isEqual: @"Token has been revoked."],
	   "a refusal comes back as the reason Google gives");
      [aGoogle stop];

      [GmailOAuth setTokenEndpoint: nil];
      [defaults removeObjectForKey: @"GMAIL_OAUTH_CLIENT_ID"];
      [defaults removeObjectForKey: @"GMAIL_OAUTH_CLIENT_SECRET"];
      PASS([GmailOAuth clientID] == nil, "without a client there is no sign-in");
      [[NSFileManager defaultManager] removeItemAtPath: aDirectory  error: NULL];
    }
  END_SET("tokens")

  START_SET("account")
    {
      NSDictionary *anAccount = [GmailOAuth accountDictionaryForAddress: @"me@gmail.com"  name: @"Me"];
      NSDictionary *receive = [anAccount objectForKey: @"RECEIVE"], *send = [anAccount objectForKey: @"SEND"];
      NSDictionary *mailboxes = [anAccount objectForKey: @"MAILBOXES"];

      PASS([[anAccount objectForKey: @"ENABLED"] boolValue], "the account is on");
      PASS([[[anAccount objectForKey: @"PERSONAL"] objectForKey: @"EMAILADDR"] isEqual: @"me@gmail.com"] &&
	   [[[anAccount objectForKey: @"PERSONAL"] objectForKey: @"NAME"] isEqual: @"Me"], "name and address are the user's");
      PASS([[receive objectForKey: @"SERVERNAME"] isEqual: @"imap.gmail.com"] && [[receive objectForKey: @"PORT"] intValue] == 993 &&
	   [[receive objectForKey: @"SERVERTYPE"] intValue] == IMAP && [[receive objectForKey: @"USESECURECONNECTION"] intValue] == SECURITY_SSL,
	   "mail is received by IMAP over SSL");
      PASS([[receive objectForKey: @"AUTH_MECHANISM"] isEqual: @"XOAUTH2"] && [[send objectForKey: @"SMTP_AUTH_MECHANISM"] isEqual: @"XOAUTH2"],
	   "both servers are logged in with a token");
      PASS([[send objectForKey: @"SMTP_HOST"] isEqual: @"smtp.gmail.com"] && [[send objectForKey: @"SMTP_PORT"] intValue] == 465 &&
	   [[send objectForKey: @"SMTP_USERNAME"] isEqual: @"me@gmail.com"] && [[send objectForKey: @"TRANSPORT_METHOD"] intValue] == TRANSPORT_SMTP,
	   "mail is sent by SMTP over SSL");
      PASS([[mailboxes objectForKey: @"INBOXFOLDERNAME"] isEqual: @"imap://me@gmail.com@imap.gmail.com/INBOX"] &&
	   [[mailboxes objectForKey: @"SENTFOLDERNAME"] isEqual: @"imap://me@gmail.com@imap.gmail.com/[Gmail]/Sent Mail"],
	   "the mailboxes are Gmail's");
    }
  END_SET("account")

  DESTROY(arp);
  return 0;
}
