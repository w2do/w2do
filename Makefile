# makefile for w2do, a simple text-based todo manager
# Copyright (C) 2008, 2009 Jaromir Hradilek

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

# General settings; feel free to modify according to your situation:
SHELL   = /bin/sh
INSTALL = /usr/bin/install -c
POD2MAN = /usr/bin/pod2man
SRCS   := $(wildcard src/*.pl)
MAN1   := $(patsubst %.pl, %.1, $(SRCS))

# Installation directories; feel free to modify according to your taste and
# situation:
prefix  = /usr/local
bindir  = $(prefix)/bin
mandir  = $(prefix)/share/man
man1dir = $(mandir)/man1

# Additional information:
VERSION = 2.2.3

# Make rules;  please do not edit these unless you really know what you are
# doing:
.PHONY: all clean install uninstall

all: $(MAN1)

clean:
	-rm -f $(MAN1)

install: $(MAN1)
	@echo "Copying scripts..."
	$(INSTALL) -d $(bindir)
	$(INSTALL) -m 755 src/w2do.pl $(bindir)/w2do
	$(INSTALL) -m 755 src/w2html.pl $(bindir)/w2html
	$(INSTALL) -m 755 src/w2text.pl $(bindir)/w2text
	@echo "Copying man pages..."
	$(INSTALL) -d $(man1dir)
	$(INSTALL) -m 644 src/w2do.1 $(man1dir)
	$(INSTALL) -m 644 src/w2html.1 $(man1dir)
	$(INSTALL) -m 644 src/w2text.1 $(man1dir)

uninstall:
	@echo "Removing scripts..."
	rm -f $(bindir)/w2do
	rm -f $(bindir)/w2html
	rm -f $(bindir)/w2text
	@echo "Removing man pages..."
	rm -f $(man1dir)/w2do.1
	rm -f $(man1dir)/w2html.1
	rm -f $(man1dir)/w2text.1
	@echo "Removing empty directories..."
	-rmdir $(bindir) $(man1dir) $(mandir)

%.1: %.pl
	$(POD2MAN) --section=1 --release="Version $(VERSION)" $^ $@

