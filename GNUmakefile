#
#  GNUMail Makefile for GNUstep
#
#  Copyright (C) 2001-2006 Ludovic Marcotte
#
#  Author: Ludovic Marcotte <ludovic@Sophos.ca>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#   
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#   
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = \
	Bundles/Account \
	Bundles/Advanced \
	Bundles/Colors \
	Bundles/Compose \
	Bundles/Filtering \
	Bundles/Fonts \
	Bundles/Import \
	Bundles/MIME \
	Bundles/Receiving \
	Bundles/Sending \
	Bundles/Viewing \
	Bundles/PGP \
	Bundles/Emoticon \

VERSION = 1.3.0
PACKAGE_NAME = Mail
APP_NAME = Mail
Mail_OBJC_FILES = \
	Sources/GSProgressIndicator.m \
	Sources/GmailOAuth.m \
	Sources/MailWindowController+Appearance.m \
	Sources/MailAppearance.m \
	Sources/MessageViewWindowController+Appearance.m \
	Sources/EditWindowController+Appearance.m \
	Sources/MailboxManagerController+Appearance.m \
	Sources/GmailAccountSetup.m \
	Sources/AboutPanelController.m \
	Sources/AddressBookController.m \
	Sources/ApplicationIconController.m \
	Sources/AutoCompletingTextField.m \
	Sources/ConsoleWindowController.m \
	Sources/Constants.m \
	Sources/ExtendedCell.m \
	Sources/ExtendedFileWrapper.m \
	Sources/ExtendedMenuItem.m \
	Sources/ExtendedTableView.m \
	Sources/ExtendedTextAttachmentCell.m \
	Sources/ExtendedTextView.m \
	Sources/ExtendedOutlineView.m \
	Sources/ExtendedWindow.m \
	Sources/EditWindowController.m \
	Sources/Filter.m \
	Sources/FilterManager.m \
	Sources/FindWindowController.m \
	Sources/FolderNode.m \
	Sources/FolderNodePopUpItem.m \
	Sources/GNUMail.m \
	Sources/GNUMail+Extensions.m \
	Sources/GNUMail+MenuValidation.m \
	Sources/GNUMail+Services.m \
	Sources/ImageTextCell.m \
	Sources/ImageButton.m \
	Sources/LabelWidget.m \
	Sources/MailboxInspectorPanel.m \
	Sources/MailboxInspectorPanelController.m \
	Sources/MailboxManager.m \
	Sources/MailboxManagerCache.m \
	Sources/MailboxManagerController.m \
	Sources/MailHeaderCell.m \
	Sources/MailWindowController.m \
	Sources/MessageViewWindow.m \
	Sources/MessageViewWindowController.m \
	Sources/MimeType.m \
	Sources/MimeTypeManager.m \
	Sources/NewMailboxPanelController.m \
	Sources/NSAttributedString+Extensions.m \
	Sources/NSAttributedString+TextEnriched.m \
	Sources/NSBezierPath+Extensions.m \
	Sources/NSBundle+Extensions.m \
	Sources/NSColor+Extensions.m \
	Sources/NSFont+Extensions.m \
	Sources/NSPasteboard+Extensions.m \
	Sources/NSUserDefaults+Extensions.m \
	Sources/PasswordPanelController.m \
	Sources/PreferencesWindowController.m \
	Sources/STScriptingSupport.m \
	Sources/Task.m \
	Sources/TaskManager.m \
	Sources/ThreadArcsCell.m \
	Sources/Utilities.m \
	Sources/WelcomePanel.m \
  Sources/GNUMail_main.m

Mail_RESOURCE_FILES = \
	Resources/*.lproj \
	Resources/Icons/*.tiff \
	Resources/Goodies/Welcome \
	ScriptingInfo.plist

Mail_LANGUAGES = \
	Resources/English

Mail_LIB_DIRS += -L../$(GNUSTEP_LIBRARIES_ROOT)
Mail_GUI_LIBS += -lPantomime -lAddresses -lAddressView
Mail_LOCALIZED_RESOURCE_FILES = Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I./Headers
ADDITIONAL_OBJCFLAGS += -Wall -Wno-import -I/usr/kerberos/include -I/usr/local/ssl/include

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
