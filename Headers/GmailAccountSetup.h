/*
**  GmailAccountSetup.h
**
**  The one click that sets a Gmail account up: sign-in in the browser, then
**  the account in the application's accounts with its Inbox open.
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
*/

#ifndef _GNUMail_H_GmailAccountSetup
#define _GNUMail_H_GmailAccountSetup

#import <Foundation/Foundation.h>

@interface GmailAccountSetup : NSObject

/*
 * Asks for the sign-in in the browser and, when it has been done, adds the
 * account to the application's accounts.  Shows its own messages.
 */
+ (void) addAccount;

/*
 * Starts to follow the accounts: the access of a Gmail account that is
 * deleted in the preferences is removed with it.
 */
+ (void) startObservingAccounts;

@end

#endif
