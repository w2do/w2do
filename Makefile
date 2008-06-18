# makefile for w2do, a simple text-based todo manager
# Copyright (C) 2008 Jaromir Hradilek

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
# 
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
# 
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.


# General settings; feel free to modify according to your actual situation:
SHELL   = /bin/sh
INSTALL = /usr/bin/install -c

# Installation directories; feel free to modify according to your taste and
# actual situation:
prefix  = /usr/local
bindir  = $(prefix)/bin
mandir  = $(prefix)/share/man
man1dir = $(mandir)/man1

# Make rules;  please do not edit these unless you really know what you are
# doing:
all:
	@echo "Type \`make install' to perform installation."

install:
	@echo "Copying binaries..."
	$(INSTALL) -d $(bindir)
	$(INSTALL) -m 755 ./w2do $(bindir)
	@echo "Copying man pages..."
	$(INSTALL) -d $(man1dir)
	$(INSTALL) -m 644 ./man/man1/w2do.1.gz $(man1dir)

uninstall:
	@echo "Removing binaries..."
	rm -f $(bindir)/w2do
	@echo "Removing man pages..."
	rm -f $(man1dir)/w2do.1.gz
	@echo "Removing empty directories..."
	-rmdir $(bindir) $(man1dir) $(mandir)

