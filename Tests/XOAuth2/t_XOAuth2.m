/*
**  t_XOAuth2.m
**
**  Pantomime logs in to an IMAP and an SMTP server with the XOAUTH2
**  mechanism, as Gmail wants it: the access token goes with the command, and a
**  refusal is answered with an empty line and ends in a failed login.
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#import <Foundation/Foundation.h>
#import "Testing.h"

#import <Pantomime/CWIMAPStore.h>
#import <Pantomime/CWSMTP.h>
#import <Pantomime/CWService.h>
#import <Pantomime/NSData+Extensions.h>

#import <unistd.h>
#import <string.h>
#import <sys/socket.h>
#import <sys/select.h>
#import <netinet/in.h>
#import <arpa/inet.h>

/* A server that says just enough of IMAP or SMTP for a login. */
@interface FakeMailServer : NSObject
{
  int listener;
  int port;
  BOOL imap;
  BOOL refuse;
  NSString *payload;          // what came after XOAUTH2, decoded
  NSString *refusalAnswer;    // what the client said to the challenge
}
- (id) initIMAP: (BOOL) isIMAP  refusing: (BOOL) shouldRefuse;
- (int) port;
- (NSString *) payload;
- (NSString *) refusalAnswer;
- (void) stop;
@end

@implementation FakeMailServer

- (id) initIMAP: (BOOL) isIMAP  refusing: (BOOL) shouldRefuse
{
  struct sockaddr_in anAddress;
  socklen_t aLength = sizeof(anAddress);

  self = [super init];
  imap = isIMAP;
  refuse = shouldRefuse;
  listener = socket(AF_INET, SOCK_STREAM, 0);
  memset(&anAddress, 0, sizeof(anAddress));
  anAddress.sin_family = AF_INET;
  anAddress.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  bind(listener, (struct sockaddr *)&anAddress, sizeof(anAddress));
  listen(listener, 2);
  getsockname(listener, (struct sockaddr *)&anAddress, &aLength);
  port = ntohs(anAddress.sin_port);
  [NSThread detachNewThreadSelector: @selector(serve:)  toTarget: self  withObject: nil];
  return self;
}

- (int) port { return port; }
- (NSString *) payload { return payload; }
- (NSString *) refusalAnswer { return refusalAnswer; }
- (void) stop { close(listener); listener = -1; }

static void say(int theConnection, NSString *theText)
{
  NSString *aLine = [theText stringByAppendingString: @"\r\n"];
  send(theConnection, [aLine UTF8String], [aLine length], 0);
}

/* One line from the client, without its end; nil when the connection ends. */
static NSString *line(int theConnection, NSMutableData *theBuffer)
{
  for (;;)
    {
      NSRange aRange = [theBuffer rangeOfData: [NSData dataWithBytes: "\r\n" length: 2]
				      options: 0
					range: NSMakeRange(0, [theBuffer length])];
      char aChunk[2048];
      ssize_t aCount;

      if (aRange.location != NSNotFound)
	{
	  NSString *aLine = AUTORELEASE([[NSString alloc] initWithData: [theBuffer subdataWithRange: NSMakeRange(0, aRange.location)]
							    encoding: NSUTF8StringEncoding]);
	  [theBuffer replaceBytesInRange: NSMakeRange(0, NSMaxRange(aRange))  withBytes: NULL  length: 0];
	  return aLine;
	}
      aCount = recv(theConnection, aChunk, sizeof(aChunk), 0);
      if (aCount <= 0)
	{
	  return nil;
	}
      [theBuffer appendBytes: aChunk  length: aCount];
    }
}

- (void) serve: (id) ignored
{
  CREATE_AUTORELEASE_POOL(pool);
  NSMutableData *aBuffer = [NSMutableData data];
  NSString *aLine;
  int aConnection;
  fd_set aSet;
  struct timeval aWait = { 5, 0 };

  FD_ZERO(&aSet);
  FD_SET(listener, &aSet);
  if (select(listener + 1, &aSet, NULL, NULL, &aWait) <= 0 || (aConnection = accept(listener, NULL, NULL)) < 0)
    {
      RELEASE(pool);
      return;
    }

  say(aConnection, imap ? @"* OK fake IMAP ready" : @"220 fake SMTP ready");

  while ((aLine = line(aConnection, aBuffer)) != nil)
    {
      NSArray *someWords = [aLine componentsSeparatedByString: @" "];
      NSString *aTag = [someWords objectAtIndex: 0];
      NSString *aCommand = ([someWords count] > 1 ? [[someWords objectAtIndex: 1] uppercaseString] : @"");

      if (imap && [aCommand isEqualToString: @"AUTHENTICATE"] && [someWords count] >= 4)
	{
	  NSData *aData = [[[someWords objectAtIndex: 3] dataUsingEncoding: NSASCIIStringEncoding] decodeBase64];

	  ASSIGN(payload, AUTORELEASE([[NSString alloc] initWithData: aData  encoding: NSUTF8StringEncoding]));
	  if ([[someWords objectAtIndex: 2] isEqualToString: @"XOAUTH2"] == NO)
	    {
	      say(aConnection, [aTag stringByAppendingString: @" NO unsupported"]);
	    }
	  else if (refuse)
	    {
	      say(aConnection, @"+ eyJzdGF0dXMiOiI0MDEifQ==");
	      ASSIGN(refusalAnswer, (line(aConnection, aBuffer) ?: @"(nothing)"));
	      say(aConnection, [aTag stringByAppendingString: @" NO [AUTHENTICATIONFAILED] Invalid credentials"]);
	    }
	  else
	    {
	      say(aConnection, [aTag stringByAppendingString: @" OK AUTHENTICATE completed"]);
	    }
	}
      else if (imap && [aCommand isEqualToString: @"CAPABILITY"])
	{
	  say(aConnection, @"* CAPABILITY IMAP4rev1 AUTH=XOAUTH2");
	  say(aConnection, [aTag stringByAppendingString: @" OK CAPABILITY completed"]);
	}
      else if (imap && [aCommand isEqualToString: @"LOGOUT"])
	{
	  say(aConnection, @"* BYE");
	  say(aConnection, [aTag stringByAppendingString: @" OK"]);
	  break;
	}
      else if (imap)
	{
	  say(aConnection, [aTag stringByAppendingString: @" OK"]);
	}
      else if ([[aTag uppercaseString] isEqualToString: @"EHLO"] || [[aTag uppercaseString] isEqualToString: @"HELO"])
	{
	  say(aConnection, @"250-fake");
	  say(aConnection, @"250 AUTH XOAUTH2");
	}
      else if ([[aTag uppercaseString] isEqualToString: @"AUTH"] && [someWords count] >= 3)
	{
	  NSData *aData = [[[someWords objectAtIndex: 2] dataUsingEncoding: NSASCIIStringEncoding] decodeBase64];

	  ASSIGN(payload, AUTORELEASE([[NSString alloc] initWithData: aData  encoding: NSUTF8StringEncoding]));
	  if (refuse)
	    {
	      say(aConnection, @"334 eyJzdGF0dXMiOiI0MDEifQ==");
	      ASSIGN(refusalAnswer, (line(aConnection, aBuffer) ?: @"(nothing)"));
	      say(aConnection, @"535 5.7.8 Username and Password not accepted");
	    }
	  else
	    {
	      say(aConnection, @"235 2.7.0 Accepted");
	    }
	}
      else if ([[aTag uppercaseString] isEqualToString: @"QUIT"])
	{
	  say(aConnection, @"221 bye");
	  break;
	}
      else
	{
	  say(aConnection, @"250 OK");
	}
    }
  close(aConnection);
  RELEASE(pool);
}

@end


/* The delegate of the service: what happened to the login. */
@interface Client : NSObject
{
  NSString *outcome;
  NSString *mechanism;
  NSString *theUser;
  NSString *theToken;
}
- (id) initWithUser: (NSString *) aUser  token: (NSString *) aToken;
- (NSString *) outcome;
- (NSString *) mechanism;
@end

@implementation Client

- (id) initWithUser: (NSString *) aUser  token: (NSString *) aToken
{
  self = [super init];
  ASSIGN(theUser, aUser);
  ASSIGN(theToken, aToken);
  return self;
}

- (NSString *) outcome { return outcome; }
- (NSString *) mechanism { return mechanism; }

- (void) serviceInitialized: (NSNotification *) theNotification
{
  [[theNotification object] authenticate: theUser  password: theToken  mechanism: @"XOAUTH2"];
}

- (void) authenticationCompleted: (NSNotification *) theNotification
{
  ASSIGN(outcome, @"completed");
  ASSIGN(mechanism, [[theNotification userInfo] objectForKey: @"Mechanism"]);
}

- (void) authenticationFailed: (NSNotification *) theNotification
{
  ASSIGN(outcome, @"failed");
  ASSIGN(mechanism, [[theNotification userInfo] objectForKey: @"Mechanism"]);
}

@end


static NSString *login(BOOL isIMAP, BOOL refuse, FakeMailServer **theServer, NSString **theMechanism)
{
  FakeMailServer *aServer = [[FakeMailServer alloc] initIMAP: isIMAP  refusing: refuse];
  Client *aClient = [[Client alloc] initWithUser: @"me@gmail.com"  token: @"tok-1"];
  CWService *aService;
  NSDate *aDeadline = [NSDate dateWithTimeIntervalSinceNow: 8.0];

  aService = (isIMAP ? (CWService *)[[CWIMAPStore alloc] initWithName: @"127.0.0.1"  port: [aServer port]]
		     : (CWService *)[[CWSMTP alloc] initWithName: @"127.0.0.1"  port: [aServer port]]);
  [aService setDelegate: aClient];
  // Not in the background: the address of the server is known, and the
  // background connection waits for the helper that looks names up.
  [aService connect];

  while ([aClient outcome] == nil && [aDeadline timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
    }
  // The server notes what it was refused with a moment after the client has heard of it.
  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];

  *theServer = aServer;
  *theMechanism = [aClient mechanism];
  return [aClient outcome];
}


int main(void)
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *expected = @"user=me@gmail.com\001auth=Bearer tok-1\001\001";
  FakeMailServer *aServer = nil;
  NSString *aMechanism = nil;

  START_SET("imap")
    {
      PASS([login(YES, NO, &aServer, &aMechanism) isEqual: @"completed"], "the IMAP login is accepted");
      PASS([aMechanism isEqual: @"XOAUTH2"], "with the XOAUTH2 mechanism");
      PASS([[aServer payload] isEqual: expected], "the token goes with the command, in the form Google wants");
      [aServer stop];

      PASS([login(YES, YES, &aServer, &aMechanism) isEqual: @"failed"], "a refused IMAP login fails");
      PASS([[aServer refusalAnswer] isEqual: @""], "after an empty answer to the challenge");
      [aServer stop];
    }
  END_SET("imap")

  START_SET("smtp")
    {
      PASS([login(NO, NO, &aServer, &aMechanism) isEqual: @"completed"], "the SMTP login is accepted");
      PASS([aMechanism isEqual: @"XOAUTH2"], "with the XOAUTH2 mechanism");
      PASS([[aServer payload] isEqual: expected], "the token goes with the command, in the form Google wants");
      [aServer stop];

      PASS([login(NO, YES, &aServer, &aMechanism) isEqual: @"failed"], "a refused SMTP login fails");
      PASS([[aServer refusalAnswer] isEqual: @""], "after an empty answer to the challenge");
      [aServer stop];
    }
  END_SET("smtp")

  DESTROY(arp);
  return 0;
}
