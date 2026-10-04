# Gmail in GNUMail

GNUMail signs in to Google with OAuth 2.0 and reads and sends mail through
Gmail's IMAP and SMTP servers with the XOAUTH2 login. No password is asked
for or stored; only a revocable refresh token is kept, in
`~/Library/Mail/GmailTokens/<address>` (readable by the user only).

## For the user

* First start, or *Mail > Add Gmail Account...* at any time.
* The browser opens, sign in to Google and allow access, come back: the
  account is set up and the Inbox opens.
* Deleting the account in the preferences removes its stored access.
* Access can also be withdrawn at https://myaccount.google.com/permissions.

## For the one who ships the application: the OAuth client

Google gives a client ID only to a project of a developer, so one has to be
created once for the application (not by every user):

1. https://console.cloud.google.com/ : create a project.
2. *APIs & Services > OAuth consent screen*: user type *External*, give the
   application a name and a support address. Under *Data access* add the
   scopes `https://mail.google.com/`, `email` and `profile`.
3. *APIs & Services > Credentials > Create credentials > OAuth client ID*:
   application type **Desktop app**. Note the client ID and client secret.
   (For a Desktop client Google does not treat the secret as confidential.)
4. Give the client to the application, either
   * as defaults (per user or for a test):
     `defaults write org.gnustep.Mail GMAIL_OAUTH_CLIENT_ID "<id>"` and
     `defaults write org.gnustep.Mail GMAIL_OAUTH_CLIENT_SECRET "<secret>"`, or
   * for everybody, in `Mail.app/Resources/GmailOAuth.plist`:
     `{ ClientID = "<id>"; ClientSecret = "<secret>"; }`

Until the client has been set, *Add Gmail Account* says so and does nothing.

### Testing and publishing

* While the consent screen is in status *Testing*, only the accounts listed
  as *Test users* can sign in, and Google lets their access expire after
  seven days. That is right for trying it out.
* For other people the consent screen has to be *In production*. The scope
  `https://mail.google.com/` is a *restricted* scope, so Google asks for a
  verification of the application (including, for applications that keep
  mail on a server of their own, a yearly security assessment; GNUMail keeps
  none, it talks to Gmail directly).

## How it works

* `GmailOAuth` - the protocol: PKCE (S256), the redirect to
  `http://127.0.0.1:<port>` (a loopback address, as Google requires for
  desktop applications), the token requests, the stored refresh token and
  the account that is made.
* `GmailAccountSetup` - the window that waits for the browser, the account
  in the application's accounts, and the Inbox that opens.
* Pantomime has the `XOAUTH2` mechanism for IMAP and SMTP. The
  "password" the application hands to the servers is the access token,
  which `Utilities +passwordForKey:...` asks `GmailOAuth` for (refreshed when
  it has expired).

Tests: `gnustep-tests Tests/GmailOAuth Tests/XOAuth2`.
