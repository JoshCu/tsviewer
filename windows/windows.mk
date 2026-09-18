# ---------------------------------------------------------------------------
# Windows cross-compilation, included by the top-level Makefile.
#
#   make windows            build the staging folder $(WIN_DIST)
#   make windows-zip        package that folder as a single .zip
#   make windows-installer  package that folder as a single setup .exe
#   make distclean          also delete the downloaded GTK3 bundle
#
# Requirements: a mingw-w64 cross compiler, wget, unzip, zip, and for the
# installer NSIS (makensis).
#   Debian/Ubuntu:  sudo apt install gcc-mingw-w64 wget unzip zip nsis
#   Fedora:         sudo dnf install mingw64-gcc wget unzip zip mingw32-nsis
#   openSUSE:       sudo zypper install mingw64-cross-gcc wget unzip zip
#
# The GTK3 headers and DLLs are downloaded as a prebuilt bundle from the
# petabyt/windows-gtk repository, so no GTK3 development package for Windows
# needs to be installed locally.  Of the bundles offered there, only
# win64-gtk-2021.zip carries GTK 3.24 DLLs; the two 2013 bundles ship GTK 3.10
# DLLs, which lack symbols this program needs and therefore fail to link.
#
# To build without an attached console window (GUI subsystem), at the cost of
# losing --help and error output on stderr:
#   make windows WIN_SUBSYSTEM=-mwindows
#
# See windows/README.md for what each file in this directory is for.
# ---------------------------------------------------------------------------

WIN_DIR=windows

WIN_HOST?=x86_64-w64-mingw32
WIN_ZIP?=win64-gtk-2021.zip
WIN_URL?=https://github.com/petabyt/windows-gtk/raw/master/$(WIN_ZIP)
WIN_SUBSYSTEM?=
# Extra flags passed to both Windows compilations, e.g. an alternative sysroot
WIN_EXTRA_CFLAGS?=
MAKENSIS?=makensis

# The bundle unpacks into a directory named "win32" even in the 64-bit zip
WIN_SDK=$(WIN_DIR)/win32
WIN_CC=$(WIN_HOST)-gcc

WIN_TARGET=$(WIN_DIR)/$(TARGET).exe
WIN_HELPER=$(WIN_DIR)/$(TARGET)-open.exe
WIN_HELPER_SRC=$(WIN_DIR)/$(TARGET)-open.c
WIN_PROMPT=$(WIN_DIR)/$(TARGET)-prompt.cmd
WIN_NSI=$(WIN_DIR)/$(TARGET).nsi
WIN_DIST=$(WIN_DIR)/dist

WIN_CFLAGS=-Wall -Wextra -O2 -std=gnu99 -D__USE_MINGW_ANSI_STDIO=1 \
           -I$(WIN_SDK)/include $(WIN_SUBSYSTEM) $(WIN_EXTRA_CFLAGS)
WIN_LIBS=$(WIN_SDK)/lib/*.dll -lm

# Version and file limit are read from the source so they cannot drift from it
VERSION=$(shell sed -n 's/^\#define TSVIEWER_VERSION "\(.*\)"/\1/p' $(SRC))
MAX_INPUT_FILES=$(shell sed -n 's/^\#define MAX_INPUT_FILES \([0-9]*\).*/\1/p' $(SRC))

# The two shippable artifacts are left in the top-level directory
WIN_PKG=$(TARGET)-$(VERSION)-win64
WIN_ZIPFILE=$(WIN_PKG).zip
WIN_SETUP=$(WIN_PKG)-setup.exe

windows: $(WIN_DIST)

# Collect the executables, the GTK3 runtime DLLs and the examples in one folder
$(WIN_DIST): $(WIN_TARGET) $(WIN_HELPER) $(WIN_PROMPT) | $(WIN_SDK)
	rm -rf $(WIN_DIST)
	mkdir -p $(WIN_DIST)
	cp $(WIN_TARGET) $(WIN_HELPER) $(WIN_PROMPT) $(WIN_DIST)/
	cp $(WIN_SDK)/lib/*.dll $(WIN_DIST)/
	cp -r examples $(WIN_DIST)/examples

$(WIN_TARGET): $(SRC) $(WIN_DIR)/tsviewer_win32_compat.h | $(WIN_SDK)
	$(WIN_CC) $(WIN_CFLAGS) -o $(WIN_TARGET) $(SRC) $(WIN_LIBS)

# Shell helper that gathers a multi-file Explorer selection into one viewer.
# Always built for the GUI subsystem so Explorer shows no console window.
$(WIN_HELPER): $(WIN_HELPER_SRC)
	$(WIN_CC) -Wall -Wextra -O2 -std=gnu99 -municode -mwindows \
	    -DMAX_INPUT_FILES=$(MAX_INPUT_FILES) $(WIN_EXTRA_CFLAGS) \
	    -o $(WIN_HELPER) $(WIN_HELPER_SRC) -lshell32 -luser32

# Single-file zip archive: unpack anywhere on Windows and run, no installation
windows-zip: $(WIN_ZIPFILE)

$(WIN_ZIPFILE): $(WIN_DIST)
	rm -rf $(WIN_DIR)/$(WIN_PKG) $(WIN_ZIPFILE)
	cp -r $(WIN_DIST) $(WIN_DIR)/$(WIN_PKG)
	cd $(WIN_DIR) && zip -q -r ../$(WIN_ZIPFILE) $(WIN_PKG)
	rm -rf $(WIN_DIR)/$(WIN_PKG)

# Single-file installer: Start Menu entry, right-click menu, and an uninstaller
windows-installer: $(WIN_SETUP)

$(WIN_SETUP): $(WIN_DIST) $(WIN_NSI)
	$(MAKENSIS) -V2 -DVERSION=$(VERSION) \
	    -DDIST=$(CURDIR)/$(WIN_DIST) \
	    -DLICENSE=$(CURDIR)/LICENSE-2.0.txt \
	    -DOUTFILE=$(CURDIR)/$(WIN_SETUP) $(WIN_NSI)

# Download the prebuilt GTK3 SDK for Windows (headers and DLLs)
$(WIN_SDK):
	wget -4 -O $(WIN_DIR)/$(WIN_ZIP) $(WIN_URL)
	unzip -q $(WIN_DIR)/$(WIN_ZIP) -d $(WIN_DIR)
	rm -f $(WIN_DIR)/$(WIN_ZIP)

# Adds itself to the top-level "clean" without that target knowing about it
clean: clean-windows

clean-windows:
	rm -f $(WIN_TARGET) $(WIN_HELPER)
	rm -rf $(WIN_DIST) $(WIN_DIR)/$(WIN_PKG)
	rm -f $(WIN_ZIPFILE) $(WIN_SETUP)

distclean: clean
	rm -rf $(WIN_SDK) $(WIN_DIR)/$(WIN_ZIP)

.PHONY: windows windows-zip windows-installer clean-windows distclean
