# Mail

A reworked version of [GNUMail](http://www.gnustep.org/experience/GNUMail.html) for the [Gershwin Desktop](https://github.com/gershwin-desktop).

It is the GNUMail mail application for GNUstep, with the Pantomime mail library, adapted to look and behave like the rest of the Gershwin Desktop.

## What is different from GNUMail

- **Gmail**: "Add Gmail Account..." in the application menu signs in with Google in the browser (OAuth 2.0) and sets up IMAP and SMTP with the XOAUTH2 login; no passwords are stored. See [Documentation/Gmail.md](Documentation/Gmail.md) for what is needed to build with a Google client ID.
- **Look**: windows and panels follow the Gershwin metrics: toolbars, a status line, alternating rows, and controls at the system font size.
- **Inbox**: the Inbox window opens whenever the application starts.

## Building

With the GNUstep environment of the Gershwin Desktop loaded:

```
cd pantomime && gmake && sudo -E gmake install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
cd .. && gmake && sudo -E gmake install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
```

## License

GNU General Public License, version 2 or later, as GNUMail. See [Documentation/COPYING](Documentation/COPYING).

Copyright (C) 2001-2006 Ludovic Marcotte, 2011-2017 Riccardo Mottola, and contributors.
