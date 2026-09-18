CC=gcc
CFLAGS=-Wall -Wextra -O2 -std=c99 -pedantic $(shell pkg-config --cflags gtk+-3.0)
LIBS=$(shell pkg-config --libs gtk+-3.0) -lm

TARGET=tsviewer
SRC=tsviewer_main.c

# ---------------------------------------------------------------------------
# Windows cross-compilation
#
#   make windows
#
# Builds a self-contained Windows folder in $(WIN_DIST) containing
# tsviewer.exe, the GTK3 runtime DLLs and the example data files.
#
# Requirements on the build machine: a mingw-w64 cross compiler, wget, unzip.
#   Debian/Ubuntu:  sudo apt install gcc-mingw-w64 wget unzip
#   Fedora:         sudo dnf install mingw64-gcc wget unzip
#   openSUSE:       sudo zypper install mingw64-cross-gcc wget unzip
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
# ---------------------------------------------------------------------------
WIN_HOST?=x86_64-w64-mingw32
WIN_ZIP?=win64-gtk-2021.zip
WIN_URL?=https://github.com/petabyt/windows-gtk/raw/master/$(WIN_ZIP)
# Directory the bundle unpacks into; it is named "win32" even in the 64-bit zip
WIN_SDK?=win32
WIN_SUBSYSTEM?=
WIN_CC=$(WIN_HOST)-gcc
WIN_TARGET=$(TARGET).exe
WIN_DIST=dist-windows
WIN_CFLAGS=-Wall -Wextra -O2 -std=gnu99 -D__USE_MINGW_ANSI_STDIO=1 \
           -I$(WIN_SDK)/include $(WIN_SUBSYSTEM)
WIN_LIBS=$(WIN_SDK)/lib/*.dll -lm

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LIBS)

windows: $(WIN_DIST)

# Collect the executable, the GTK3 runtime DLLs and the examples in one folder
$(WIN_DIST): $(WIN_TARGET) $(WIN_SDK)
	rm -rf $(WIN_DIST)
	mkdir -p $(WIN_DIST)
	cp $(WIN_TARGET) $(WIN_DIST)/
	cp $(WIN_SDK)/lib/*.dll $(WIN_DIST)/
	cp -r examples $(WIN_DIST)/examples

$(WIN_TARGET): $(SRC) | $(WIN_SDK)
	$(WIN_CC) $(WIN_CFLAGS) -o $(WIN_TARGET) $(SRC) $(WIN_LIBS)

# Download the prebuilt GTK3 SDK for Windows (headers and DLLs)
$(WIN_SDK):
	wget -4 -O $(WIN_ZIP) $(WIN_URL)
	unzip -q $(WIN_ZIP)
	rm -f $(WIN_ZIP)

clean:
	rm -f $(TARGET) *.o
	rm -f $(WIN_TARGET)
	rm -rf $(WIN_DIST)

# Also remove the downloaded Windows SDK
distclean: clean
	rm -rf $(WIN_SDK) $(WIN_ZIP)

.PHONY: all windows clean distclean
